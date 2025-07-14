import Foundation
import Network
import SystemConfiguration
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var localIPAddress: String = "127.0.0.1"
    @Published var externalIPAddress: String?
    @Published var networkInterfaces: [NetworkInterface] = []
    @Published var isConnectedToInternet = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Performance optimization: Cache and debouncing
    private var lastLocalIPUpdate: Date = Date.distantPast
    private var lastExternalIPUpdate: Date = Date.distantPast
    private var lastInterfaceUpdate: Date = Date.distantPast
    private let updateInterval: TimeInterval = 5.0 // Minimum time between updates
    private var cachedExternalIP: String?
    private var externalIPCacheExpiry: Date = Date.distantPast
    
    // Debouncing subjects
    private let networkUpdateSubject = PassthroughSubject<Void, Never>()
    private let ipUpdateSubject = PassthroughSubject<Void, Never>()
    
    private init() {
        setupNetworkMonitoring()
        setupDebouncedUpdates()
        updateNetworkInfo()
    }
    
    deinit {
        monitor.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let wasConnected = self.isConnectedToInternet
                self.isConnectedToInternet = path.status == .satisfied
                
                // Only update network info if connection status changed
                if wasConnected != self.isConnectedToInternet {
                    self.networkUpdateSubject.send()
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func setupDebouncedUpdates() {
        // Debounce network updates to avoid excessive refreshes
        networkUpdateSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateNetworkInfo()
            }
            .store(in: &cancellables)
        
        // Debounce IP updates separately
        ipUpdateSubject
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateIPAddresses()
            }
            .store(in: &cancellables)
    }
    
    private func updateNetworkInfo() {
        let now = Date()
        
        // Rate limiting: Only update if enough time has passed
        guard now.timeIntervalSince(lastLocalIPUpdate) >= updateInterval else {
            return
        }
        
        Task {
            await updateLocalIPAddress()
            await updateExternalIPAddress()
            await updateNetworkInterfaces()
            
            await MainActor.run {
                self.lastLocalIPUpdate = now
            }
        }
    }
    
    private func updateIPAddresses() {
        Task {
            await updateLocalIPAddress()
            await updateExternalIPAddress()
        }
    }
    
    // MARK: - IP Address Management
    
    private func updateLocalIPAddress() async {
        // Use cached result if available and recent
        if let ip = getLocalIPAddressCached() {
            await MainActor.run {
                self.localIPAddress = ip
            }
        }
    }
    
    private func getLocalIPAddressCached() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    
                    // Skip loopback and prioritize common network interfaces
                    if name.hasPrefix("en") || name.hasPrefix("wifi") || name.hasPrefix("eth") {
                        var addr = interface.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        
                        if getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            let ipString = String(cString: hostname)
                            
                            // Prefer IPv4 addresses and skip link-local addresses
                            if addrFamily == UInt8(AF_INET) && !ipString.hasPrefix("169.254") {
                                address = ipString
                                break
                            } else if address == nil && !ipString.hasPrefix("fe80") {
                                address = ipString
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address ?? "127.0.0.1"
    }
    
    private func updateExternalIPAddress() async {
        let now = Date()
        
        // Use cached external IP if still valid
        if let cached = cachedExternalIP, now < externalIPCacheExpiry {
            await MainActor.run {
                self.externalIPAddress = cached
            }
            return
        }
        
        // Rate limiting for external IP requests
        guard now.timeIntervalSince(lastExternalIPUpdate) >= 30.0 else {
            return
        }
        
        do {
            let ip = try await fetchExternalIPAddress()
            await MainActor.run {
                self.externalIPAddress = ip
                self.cachedExternalIP = ip
                self.externalIPCacheExpiry = now.addingTimeInterval(300) // Cache for 5 minutes
                self.lastExternalIPUpdate = now
            }
        } catch {
            // Silently fail for external IP - not critical
            await MainActor.run {
                self.lastExternalIPUpdate = now
            }
        }
    }
    
    private func fetchExternalIPAddress() async throws -> String {
        // Use multiple services for reliability
        let services = [
            "https://api.ipify.org",
            "https://checkip.amazonaws.com",
            "https://icanhazip.com"
        ]
        
        for service in services {
            do {
                guard let url = URL(string: service) else { continue }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let ipString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let ip = ipString, isValidIPAddress(ip) {
                    return ip
                }
            } catch {
                // Try next service
                continue
            }
        }
        
        throw NetworkError.externalIPUnavailable
    }
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        // Basic IP validation
        let components = ip.components(separatedBy: ".")
        return components.count == 4 && components.allSatisfy { component in
            guard let num = Int(component) else { return false }
            return num >= 0 && num <= 255
        }
    }
    
    private func updateNetworkInterfaces() async {
        let now = Date()
        
        // Rate limiting for interface updates
        guard now.timeIntervalSince(lastInterfaceUpdate) >= updateInterval else {
            return
        }
        
        let interfaces = await getNetworkInterfaces()
        await MainActor.run {
            self.networkInterfaces = interfaces
            self.lastInterfaceUpdate = now
        }
    }
    
    private func getNetworkInterfaces() async -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let name = String(cString: interface.ifa_name)
                
                // Skip loopback and system interfaces
                guard !name.hasPrefix("lo") && !name.hasPrefix("utun") else {
                    continue
                }
                
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    if getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                  &hostname, socklen_t(hostname.count),
                                  nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        let ipString = String(cString: hostname)
                        let isActive = (interface.ifa_flags & UInt32(IFF_UP)) != 0 && 
                                      (interface.ifa_flags & UInt32(IFF_RUNNING)) != 0
                        
                        let interfaceType = determineInterfaceType(name)
                        let networkInterface = NetworkInterface(
                            name: name,
                            ipAddress: ipString,
                            isActive: isActive,
                            type: interfaceType
                        )
                        interfaces.append(networkInterface)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return interfaces
    }
    
    private func determineInterfaceType(_ name: String) -> InterfaceType {
        if name.hasPrefix("en") && name.contains("eth") {
            return .ethernet
        } else if name.hasPrefix("en") || name.hasPrefix("wifi") {
            return .wifi
        } else if name.hasPrefix("ppp") || name.hasPrefix("utun") {
            return .vpn
        } else {
            return .other
        }
    }
    
    // MARK: - Public Methods
    
    func refreshNetworkInfo() {
        ipUpdateSubject.send()
    }
    
    func isPortOpen(_ port: Int) async -> Bool {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(sockfd) }
        
        guard sockfd != -1 else { return false }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sockfd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
}

// MARK: - Data Models

struct NetworkInterface {
    let name: String
    let ipAddress: String
    let isActive: Bool
    let type: InterfaceType
}

enum InterfaceType {
    case ethernet
    case wifi
    case vpn
    case other
}

enum NetworkError: Error {
    case externalIPUnavailable
    case invalidResponse
    case connectionFailed
}