import SwiftUI

struct StatusView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @StateObject private var networkManager = NetworkManager.shared
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            // System Overview
            GroupBox("System Overview") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text("Network Status")
                        Spacer()
                        Circle()
                            .fill(networkManager.isConnectedToInternet ? .green : .red)
                            .frame(width: 10, height: 10)
                        Text(networkManager.isConnectedToInternet ? "Connected" : "Disconnected")
                            .foregroundColor(networkManager.isConnectedToInternet ? .green : .red)
                    }
                    
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.orange)
                        Text("Running Servers")
                        Spacer()
                        Text("\(runningServersCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.purple)
                        Text("Total Projects")
                        Spacer()
                        Text("\(projectManager.projects.count)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            // Network Information
            GroupBox("Network Information") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Local IP:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(networkManager.localIPAddress)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    
                    if let externalIP = networkManager.externalIPAddress {
                        HStack {
                            Text("External IP:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(externalIP)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    
                    HStack {
                        Text("Active Interfaces:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(activeInterfacesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            // Port Overview
            GroupBox("Port Overview") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Port Range: 3000-3300")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Available: \(availablePortsCount)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    // Port Usage Chart
                    PortUsageChart(projects: projectManager.projects)
                }
                .padding()
            }
            
            // Running Servers
            if runningServersCount > 0 {
                GroupBox("Running Servers") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(runningProjects) { project in
                            RunningServerRow(project: project)
                        }
                    }
                    .padding()
                }
            }
            
            // Network Interfaces
            GroupBox("Network Interfaces") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(networkManager.networkInterfaces, id: \.name) { interface in
                        NetworkInterfaceRow(interface: interface)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private var runningServersCount: Int {
        projectManager.projects.filter { $0.status == .running }.count
    }
    
    private var runningProjects: [Project] {
        projectManager.projects.filter { $0.status == .running }
    }
    
    private var activeInterfacesCount: Int {
        networkManager.networkInterfaces.filter { $0.isActive }.count
    }
    
    private var availablePortsCount: Int {
        let usedPorts = Set(projectManager.projects.map { $0.port })
        return (3000...3300).filter { !usedPorts.contains($0) }.count
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Refresh network information
            objectWillChange.send()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct RunningServerRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            Image(systemName: project.type.icon)
                .foregroundColor(project.type.color)
            
            VStack(alignment: .leading) {
                Text(project.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Port \(project.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if let processId = project.processId {
                    Text("PID: \(processId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let startTime = project.lastStarted {
                    Text("Up: \(startTime, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct NetworkInterfaceRow: View {
    let interface: NetworkInterface
    
    var body: some View {
        HStack {
            Image(systemName: interface.type.icon)
                .foregroundColor(interface.isActive ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(interface.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(interface.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(interface.ipAddress)
                    .font(.caption2)
                    .textSelection(.enabled)
                
                Circle()
                    .fill(interface.isActive ? .green : .gray)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct PortUsageChart: View {
    let projects: [Project]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(3000...3300, id: \.self) { port in
                Rectangle()
                    .fill(portColor(for: port))
                    .frame(height: 20)
            }
        }
        .cornerRadius(2)
    }
    
    private func portColor(for port: Int) -> Color {
        if let project = projects.first(where: { $0.port == port }) {
            switch project.status {
            case .running:
                return .green
            case .stopped:
                return .gray
            case .starting, .stopping:
                return .orange
            case .error:
                return .red
            }
        }
        return .clear
    }
}

extension InterfaceType {
    var icon: String {
        switch self {
        case .ethernet:
            return "cable.connector"
        case .wifi:
            return "wifi"
        case .loopback:
            return "arrow.triangle.2.circlepath"
        case .vpn:
            return "lock.shield"
        case .other:
            return "network"
        }
    }
}

#Preview {
    StatusView()
        .environmentObject(ProjectManager())
}