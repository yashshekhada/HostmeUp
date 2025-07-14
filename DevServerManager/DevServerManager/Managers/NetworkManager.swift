import Foundation
import Network
import SystemConfiguration

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var localIPAddress: String = "127.0.0.1"
    @Published var externalIPAddress: String?
    @Published var networkInterfaces: [NetworkInterface] = []
    @Published var isConnectedToInternet = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        setupNetworkMonitoring()
        updateNetworkInfo()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedToInternet = path.status == .satisfied
                self?.updateNetworkInfo()
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateNetworkInfo() {
        Task {
            await updateLocalIPAddress()
            await updateExternalIPAddress()
            await updateNetworkInterfaces()
        }
    }
    
    // MARK: - IP Address Management
    
    private func updateLocalIPAddress() async {
        if let ip = getLocalIPAddress() {
            await MainActor.run {
                self.localIPAddress = ip
            }
        }
    }
    
    private func getLocalIPAddress() -> String? {
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
                    
                    // Skip loopback and other non-relevant interfaces
                    if name.starts(with: "en") || name.starts(with: "wifi") {
                        var addr = interface.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        
                        if getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            let ipString = String(cString: hostname)
                            
                            // Prefer IPv4 addresses
                            if addrFamily == UInt8(AF_INET) {
                                address = ipString
                                break
                            } else if address == nil {
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
        do {
            let ip = try await fetchExternalIPAddress()
            await MainActor.run {
                self.externalIPAddress = ip
            }
        } catch {
            print("Failed to fetch external IP: \(error)")
        }
    }
    
    private func fetchExternalIPAddress() async throws -> String {
        let urls = [
            "https://ipinfo.io/ip",
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com"
        ]
        
        for urlString in urls {
            do {
                guard let url = URL(string: urlString) else { continue }
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return ip
                }
            } catch {
                continue // Try next URL
            }
        }
        
        throw NetworkError.failedToFetchExternalIP
    }
    
    // MARK: - Network Interface Management
    
    private func updateNetworkInterfaces() async {
        let interfaces = getNetworkInterfaces()
        
        await MainActor.run {
            self.networkInterfaces = interfaces
        }
    }
    
    private func getNetworkInterfaces() -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    if getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                  &hostname, socklen_t(hostname.count),
                                  nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        let ipAddress = String(cString: hostname)
                        
                        let networkInterface = NetworkInterface(
                            name: name,
                            ipAddress: ipAddress,
                            type: getInterfaceType(name),
                            isActive: (interface.ifa_flags & UInt32(IFF_UP)) != 0
                        )
                        
                        interfaces.append(networkInterface)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return interfaces
    }
    
    private func getInterfaceType(_ name: String) -> InterfaceType {
        if name.starts(with: "en") {
            return .ethernet
        } else if name.starts(with: "wi") || name.starts(with: "wl") {
            return .wifi
        } else if name.starts(with: "lo") {
            return .loopback
        } else if name.starts(with: "utun") || name.starts(with: "tun") {
            return .vpn
        } else {
            return .other
        }
    }
    
    // MARK: - Port Scanning
    
    func scanPort(_ port: Int, on host: String = "localhost") async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: .tcp)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed(_):
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }
    
    func scanPortRange(_ range: ClosedRange<Int>, on host: String = "localhost") async -> [Int] {
        var openPorts: [Int] = []
        
        await withTaskGroup(of: (Int, Bool).self) { group in
            for port in range {
                group.addTask {
                    let isOpen = await self.scanPort(port, on: host)
                    return (port, isOpen)
                }
            }
            
            for await (port, isOpen) in group {
                if isOpen {
                    openPorts.append(port)
                }
            }
        }
        
        return openPorts.sorted()
    }
    
    // MARK: - Network Utilities
    
    func getNetworkSpeed() async -> NetworkSpeed {
        // Simulate network speed test
        let startTime = Date()
        
        do {
            let url = URL(string: "https://httpbin.org/bytes/1024")!
            let (_, _) = try await URLSession.shared.data(from: url)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let speed = 1024.0 / duration // bytes per second
            
            return NetworkSpeed(
                downloadSpeed: speed,
                uploadSpeed: speed * 0.8, // Estimate upload as 80% of download
                ping: duration * 1000 // Convert to milliseconds
            )
        } catch {
            return NetworkSpeed(downloadSpeed: 0, uploadSpeed: 0, ping: 0)
        }
    }
    
    func pingHost(_ host: String) async -> PingResult {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "4", host]
        task.standardOutput = pipe
        task.standardError = pipe
        
        let startTime = Date()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            return PingResult(
                host: host,
                isReachable: task.terminationStatus == 0,
                averageTime: duration * 1000, // Convert to milliseconds
                output: output
            )
        } catch {
            return PingResult(
                host: host,
                isReachable: false,
                averageTime: 0,
                output: error.localizedDescription
            )
        }
    }
    
    // MARK: - DNS Management
    
    func resolveDNS(_ hostname: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
            
            CFHostStartInfoResolution(host, .addresses, nil)
            
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data] {
                let ipAddresses = addresses.compactMap { data -> String? in
                    return data.withUnsafeBytes { bytes in
                        let sockaddr = bytes.bindMemory(to: sockaddr.self).first!
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        
                        if getnameinfo(&sockaddr, socklen_t(data.count),
                                      &hostname, socklen_t(hostname.count),
                                      nil, 0, NI_NUMERICHOST) == 0 {
                            return String(cString: hostname)
                        }
                        return nil
                    }
                }
                continuation.resume(returning: ipAddresses)
            } else {
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Supporting Types

struct NetworkInterface {
    let name: String
    let ipAddress: String
    let type: InterfaceType
    let isActive: Bool
}

enum InterfaceType: String, CaseIterable {
    case ethernet = "Ethernet"
    case wifi = "Wi-Fi"
    case loopback = "Loopback"
    case vpn = "VPN"
    case other = "Other"
}

struct NetworkSpeed {
    let downloadSpeed: Double // bytes per second
    let uploadSpeed: Double // bytes per second
    let ping: Double // milliseconds
}

struct PingResult {
    let host: String
    let isReachable: Bool
    let averageTime: Double // milliseconds
    let output: String
}

enum NetworkError: Error, LocalizedError {
    case failedToFetchExternalIP
    case invalidHost
    case connectionTimeout
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchExternalIP:
            return "Failed to fetch external IP address"
        case .invalidHost:
            return "Invalid host"
        case .connectionTimeout:
            return "Connection timeout"
        }
    }
}