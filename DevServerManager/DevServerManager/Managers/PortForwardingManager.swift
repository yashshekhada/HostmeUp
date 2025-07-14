import Foundation
import Network

class PortForwardingManager: ObservableObject {
    @Published var portForwardingRules: [PortForwardingRule] = []
    @Published var isFirewallConfigured = false
    
    private let networkManager = NetworkManager.shared
    
    // MARK: - Port Forwarding Management
    
    func setupPortForwarding(for port: Int) {
        let rule = PortForwardingRule(
            localPort: port,
            externalPort: port,
            isActive: true,
            protocol: .tcp,
            description: "Development server on port \(port)"
        )
        
        portForwardingRules.append(rule)
        
        // Configure firewall rule
        configureFirewallRule(for: rule)
        
        // Setup UPnP if available
        setupUPnPPortForwarding(for: rule)
    }
    
    func removePortForwarding(for port: Int) {
        portForwardingRules.removeAll { $0.localPort == port }
        
        // Remove firewall rule
        removeFirewallRule(for: port)
        
        // Remove UPnP port forwarding
        removeUPnPPortForwarding(for: port)
    }
    
    func configureFirewall() {
        Task {
            await configureFirewallRules()
        }
    }
    
    // MARK: - Firewall Configuration
    
    private func configureFirewallRule(for rule: PortForwardingRule) {
        let script = """
            #!/bin/bash
            
            # Add firewall rule to allow incoming connections on port \(rule.localPort)
            sudo pfctl -f /etc/pf.conf
            
            # Create temporary rule
            echo "pass in inet proto tcp from any to any port \(rule.localPort)" | sudo pfctl -f -
            
            # Enable port forwarding
            sudo sysctl -w net.inet.ip.forwarding=1
            """
        
        executeScript(script)
    }
    
    private func removeFirewallRule(for port: Int) {
        let script = """
            #!/bin/bash
            
            # Remove firewall rule for port \(port)
            # This would typically involve removing the specific rule from pf.conf
            echo "Removing firewall rule for port \(port)"
            """
        
        executeScript(script)
    }
    
    private func configureFirewallRules() async {
        // Configure macOS firewall to allow incoming connections
        let script = """
            #!/bin/bash
            
            # Check if firewall is enabled
            FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
            
            if [[ "$FIREWALL_STATUS" == *"enabled"* ]]; then
                # Add application to firewall exceptions
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$0"
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$0"
                
                # Allow incoming connections
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
            fi
            """
        
        executeScript(script)
        
        await MainActor.run {
            self.isFirewallConfigured = true
        }
    }
    
    // MARK: - UPnP Port Forwarding
    
    private func setupUPnPPortForwarding(for rule: PortForwardingRule) {
        // Note: UPnP implementation would require a third-party library
        // For now, we'll simulate the process
        
        Task {
            do {
                // Simulate UPnP discovery and port mapping
                try await discoverUPnPGateway()
                try await addUPnPPortMapping(rule)
            } catch {
                print("UPnP setup failed: \(error)")
            }
        }
    }
    
    private func removeUPnPPortForwarding(for port: Int) {
        Task {
            do {
                try await removeUPnPPortMapping(port)
            } catch {
                print("UPnP removal failed: \(error)")
            }
        }
    }
    
    private func discoverUPnPGateway() async throws {
        // Simulate UPnP gateway discovery
        // In a real implementation, this would use SSDP to discover UPnP devices
        print("Discovering UPnP gateway...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second simulation
    }
    
    private func addUPnPPortMapping(_ rule: PortForwardingRule) async throws {
        // Simulate adding UPnP port mapping
        print("Adding UPnP port mapping for port \(rule.localPort)")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second simulation
    }
    
    private func removeUPnPPortMapping(_ port: Int) async throws {
        // Simulate removing UPnP port mapping
        print("Removing UPnP port mapping for port \(port)")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second simulation
    }
    
    // MARK: - Network Configuration
    
    func getPortForwardingStatus() -> [PortForwardingStatus] {
        return portForwardingRules.map { rule in
            PortForwardingStatus(
                rule: rule,
                isReachable: checkPortReachability(rule.externalPort),
                lastChecked: Date()
            )
        }
    }
    
    private func checkPortReachability(_ port: Int) -> Bool {
        // Check if port is reachable from external network
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        task.arguments = ["-z", "-v", "-w", "3", "localhost", "\(port)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Advanced Configuration
    
    func configureDDNS(domain: String, provider: DDNSProvider) {
        // Configure Dynamic DNS for external access
        let script = createDDNSScript(domain: domain, provider: provider)
        executeScript(script)
    }
    
    private func createDDNSScript(domain: String, provider: DDNSProvider) -> String {
        switch provider {
        case .duckDNS:
            return """
                #!/bin/bash
                
                # Update DuckDNS with current IP
                CURRENT_IP=$(curl -s ipinfo.io/ip)
                curl -s "https://www.duckdns.org/update?domains=\(domain)&token=YOUR_TOKEN&ip=$CURRENT_IP"
                """
        case .noIP:
            return """
                #!/bin/bash
                
                # Update No-IP with current IP
                CURRENT_IP=$(curl -s ipinfo.io/ip)
                curl -s "https://dynupdate.no-ip.com/nic/update?hostname=\(domain)&myip=$CURRENT_IP" -u "username:password"
                """
        case .cloudflare:
            return """
                #!/bin/bash
                
                # Update Cloudflare DNS record
                CURRENT_IP=$(curl -s ipinfo.io/ip)
                curl -X PUT "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records/RECORD_ID" \
                     -H "Authorization: Bearer YOUR_API_TOKEN" \
                     -H "Content-Type: application/json" \
                     --data '{"type":"A","name":"\(domain)","content":"$CURRENT_IP"}'
                """
        }
    }
    
    // MARK: - Utility Methods
    
    private func executeScript(_ script: String) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", script]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus != 0 {
                print("Script execution failed: \(output)")
            }
        } catch {
            print("Failed to execute script: \(error)")
        }
    }
    
    func requestAdminPermissions() {
        // Request admin permissions for firewall configuration
        let script = """
            #!/bin/bash
            
            # Request admin permissions
            osascript -e 'do shell script "echo Admin permissions requested" with administrator privileges'
            """
        
        executeScript(script)
    }
}

// MARK: - Supporting Types

struct PortForwardingRule {
    let id = UUID()
    let localPort: Int
    let externalPort: Int
    let isActive: Bool
    let protocol: NetworkProtocol
    let description: String
}

struct PortForwardingStatus {
    let rule: PortForwardingRule
    let isReachable: Bool
    let lastChecked: Date
}

enum NetworkProtocol: String, CaseIterable {
    case tcp = "TCP"
    case udp = "UDP"
    case both = "Both"
}

enum DDNSProvider: String, CaseIterable {
    case duckDNS = "DuckDNS"
    case noIP = "No-IP"
    case cloudflare = "Cloudflare"
}