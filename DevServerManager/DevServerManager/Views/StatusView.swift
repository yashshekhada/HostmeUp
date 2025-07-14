import SwiftUI
import Combine

struct StatusView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @StateObject private var networkManager = NetworkManager.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 20) {
            // System Overview
            GroupBox("System Overview") {
                VStack(alignment: .leading, spacing: 12) {
                    NetworkStatusRow(isConnected: networkManager.isConnectedToInternet)
                    
                    ServerStatusRow(runningCount: runningServersCount)
                    
                    ProjectStatusRow(totalCount: projectManager.projects.count)
                }
                .padding()
            }
            
            // Network Information
            GroupBox("Network Information") {
                VStack(alignment: .leading, spacing: 12) {
                    NetworkInfoRow(
                        label: "Local IP:",
                        value: networkManager.localIPAddress
                    )
                    
                    if let externalIP = networkManager.externalIPAddress {
                        NetworkInfoRow(
                            label: "External IP:",
                            value: externalIP
                        )
                    }
                    
                    NetworkInfoRow(
                        label: "Active Interfaces:",
                        value: "\(activeInterfacesCount)"
                    )
                }
                .padding()
            }
            
            // Port Overview
            GroupBox("Port Overview") {
                VStack(alignment: .leading, spacing: 8) {
                    PortInfoRow(
                        range: "Port Range: 3000-3300",
                        available: availablePortsCount
                    )
                    
                    // Port Usage Chart
                    PortUsageChart(projects: projectManager.projects)
                }
                .padding()
            }
            
            // Running Servers
            if !runningProjects.isEmpty {
                GroupBox("Running Servers") {
                    LazyVStack(spacing: 8) {
                        ForEach(runningProjects, id: \.id) { project in
                            RunningServerRow(project: project)
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            setupReactiveUpdates()
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    // MARK: - Computed Properties
    
    private var runningServersCount: Int {
        projectManager.projects.lazy.filter { $0.status == .running }.count
    }
    
    private var runningProjects: [Project] {
        projectManager.projects.filter { $0.status == .running }
    }
    
    private var activeInterfacesCount: Int {
        networkManager.networkInterfaces.lazy.filter { $0.isActive }.count
    }
    
    private var availablePortsCount: Int {
        let usedPorts = Set(projectManager.projects.lazy.map { $0.port })
        return (3000...3300).lazy.filter { !usedPorts.contains($0) }.count
    }
    
    // MARK: - Reactive Updates
    
    private func setupReactiveUpdates() {
        // Debounced network updates
        networkManager.objectWillChange
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak networkManager] _ in
                networkManager?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Throttled project updates
        projectManager.objectWillChange
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true)
            .sink { _ in
                // Update triggered by project changes
            }
            .store(in: &cancellables)
    }
}

// MARK: - Optimized Row Components

struct NetworkStatusRow: View {
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(.blue)
            Text("Network Status")
            Spacer()
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 10, height: 10)
            Text(isConnected ? "Connected" : "Disconnected")
                .foregroundColor(isConnected ? .green : .red)
        }
    }
}

struct ServerStatusRow: View {
    let runningCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundColor(.orange)
            Text("Running Servers")
            Spacer()
            Text("\(runningCount)")
                .foregroundColor(.secondary)
        }
    }
}

struct ProjectStatusRow: View {
    let totalCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.purple)
            Text("Total Projects")
            Spacer()
            Text("\(totalCount)")
                .foregroundColor(.secondary)
        }
    }
}

struct NetworkInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

struct PortInfoRow: View {
    let range: String
    let available: Int
    
    var body: some View {
        HStack {
            Text(range)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Available: \(available)")
                .font(.caption)
                .foregroundColor(.green)
        }
    }
}

struct PortUsageChart: View {
    let projects: [Project]
    
    var body: some View {
        let usedPorts = Set(projects.lazy.map { $0.port })
        let totalPorts = 301 // 3000-3300
        let usedCount = usedPorts.count
        let availableCount = totalPorts - usedCount
        let usagePercentage = Double(usedCount) / Double(totalPorts)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Port Usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(usagePercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.orange)
                        .frame(width: geometry.size.width * usagePercentage)
                    
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: geometry.size.width * (1 - usagePercentage))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct RunningServerRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            Image(systemName: project.type.icon)
                .foregroundColor(project.type.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Port \(project.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
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
        .padding(.vertical, 2)
    }
}



#Preview {
    StatusView()
        .environmentObject(ProjectManager())
}