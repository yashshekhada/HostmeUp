import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var portForwardingManager = PortForwardingManager()
    @State private var selectedProject: Project?
    @State private var showingProjectSettings = false
    @State private var showingAddProject = false
    @State private var showingGlobalHostingSetup = false
    
    var body: some View {
        NavigationSplitView(sidebar: {
            // Sidebar - Project List
            VStack {
                // Network Status Header
                NetworkStatusHeader(networkManager: networkManager, portForwardingManager: portForwardingManager)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                List(projectManager.projects, id: \.id, selection: $selectedProject) { project in
                    ProjectRowView(project: project)
                        .contextMenu {
                            Button("Edit") {
                                selectedProject = project
                                showingProjectSettings = true
                            }
                            Button("Delete") {
                                projectManager.deleteProject(project)
                            }
                            Button("Open in Finder") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                            }
                        }
                }
                .navigationTitle("Projects")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddProject = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .frame(minWidth: 250)
        }, detail: {
            // Main Detail Area
            Group {
                if let project = selectedProject {
                    ProjectDetailView(project: project)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("DevServer Manager")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Select a project from the sidebar to view details")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Button("Add New Project") {
                            showingAddProject = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 600)
        })
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
                .environmentObject(projectManager)
        }
        .sheet(isPresented: $showingProjectSettings) {
            if let project = selectedProject {
                ProjectSettingsView(project: project)
                    .environmentObject(projectManager)
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Project Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: project.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(project.type.color)
            }
            
            // Project Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    StatusIndicator(status: project.status)
                }
                
                HStack(spacing: 8) {
                    Text(project.type.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(":\(project.port)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if project.status == .running, let pid = project.processId {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("PID: \(pid)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Text(project.path)
                    .font(.system(size: 11))
                
                    
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StatusIndicator: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.2))
                    .frame(width: 16, height: 16)
                
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
            }
            
            Text(status.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(status.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(status.color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
    @StateObject private var networkManager = NetworkManager.shared
    @State private var showingLogs = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: project.type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(project.type.color)
                
                VStack(alignment: .leading) {
                    Text(project.name)
                        .font(.title)
                    Text(project.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusIndicator(status: project.status)
            }
            
            // Server Controls
            HStack {
                Button(action: {
                    if project.status == .running {
                        projectManager.stopServer(for: project)
                    } else {
                        projectManager.startServer(for: project)
                    }
                }) {
                    HStack {
                        Image(systemName: project.status == .running ? "stop.fill" : "play.fill")
                        Text(project.status == .running ? "Stop Server" : "Start Server")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(project.status == .starting || project.status == .stopping)
                
                Button("Restart") {
                    projectManager.restartServer(for: project)
                }
                .buttonStyle(.bordered)
                .disabled(project.status != .running)
                
                Button("Logs") {
                    showingLogs = true
                }
                .buttonStyle(.bordered)
            }
            
            // Project Information
            GroupBox("Project Information") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Path", value: project.path)
                    InfoRow(label: "Type", value: project.type.rawValue)
                    InfoRow(label: "Port", value: "\(project.port)")
                    InfoRow(label: "Command", value: project.startCommand)
                    if let processId = project.processId {
                        InfoRow(label: "Process ID", value: "\(processId)")
                    }
                }
            }
            
            // Network Information
            GroupBox("Network Information") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Local URL", value: "http://localhost:\(project.port)")
                    InfoRow(label: "Network URL", value: "http://\(NetworkManager.shared.localIPAddress):\(project.port)")
                    if let externalURL = project.externalURL {
                        InfoRow(label: "External URL", value: externalURL)
                    }
                }
            }
            
            // Prerequisites
            if !project.prerequisites.isEmpty {
                GroupBox("Prerequisites") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(project.prerequisites, id: \.self) { prerequisite in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(prerequisite)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Real-time Server Status Bar
            ServerStatusBar(project: project, networkManager: networkManager)
        }
        .padding()
        .sheet(isPresented: $showingLogs) {
            LogsView(project: project)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct AddProjectView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var path = ""
    @State private var type = ProjectType.nodejs
    @State private var port = 3000
    @State private var startCommand = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add New Project")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure your development server project")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Project Info Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("Project Information")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Project Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Enter project name", text: $name)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Project Path")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack {
                                        TextField("Select project directory", text: $path)
                                            .textFieldStyle(.roundedBorder)
                                        Button(action: selectProjectPath) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "folder")
                                                Text("Browse")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Project Type")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Picker("Project Type", selection: $type) {
                                        ForEach(ProjectType.allCases, id: \.self) { type in
                                            HStack {
                                                Image(systemName: type.icon)
                                                Text(type.rawValue)
                                            }.tag(type)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // Configuration Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Server Configuration")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Port Number")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Port", value: $port, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Command")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Command to start the server", text: $startCommand)
                                        .textFieldStyle(.roundedBorder)
                                        .onAppear {
                                            startCommand = type.defaultCommand
                                        }
                                        .onChange(of: type) { oldValue, newValue in
                                            startCommand = newValue.defaultCommand
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Project") {
                    let project = Project(
                        name: name,
                        path: path,
                        type: type,
                        port: port,
                        startCommand: startCommand
                    )
                    projectManager.addProject(project)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || path.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 550)
    }
    
    private func selectProjectPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK {
            path = panel.url?.path ?? ""
        }
    }
}

struct LogsView: View {
    let project: Project
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Server logs for \(project.name)")
                        .font(.title2)
                        .padding()
                    
                    // Logs content would go here
                    Text("Logs will appear here...")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Network Status Header

struct NetworkStatusHeader: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var portForwardingManager: PortForwardingManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Global IP Address
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    
                    if let externalIP = networkManager.externalIPAddress {
                        Text("Global IP:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(externalIP)
                            .font(.caption)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                    } else {
                        Text("Fetching Global IP...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .frame(height: 16)
                
                // Port Forwarding Status
                HStack(spacing: 6) {
                    Image(systemName: portForwardingManager.isFirewallConfigured ? "shield.fill" : "shield")
                        .font(.system(size: 12))
                        .foregroundColor(portForwardingManager.isFirewallConfigured ? .green : .orange)
                    
                    Text("Port Forwarding:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(portForwardingManager.isFirewallConfigured ? "Active" : "Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(portForwardingManager.isFirewallConfigured ? .green : .orange)
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: {
                    networkManager.updateNetworkInfo()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Refresh Network Status")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Server Status Bar

struct ServerStatusBar: View {
    let project: Project
    @ObservedObject var networkManager: NetworkManager
    @State private var localServerStatus: ServerConnectionStatus = .checking
    @State private var networkServerStatus: ServerConnectionStatus = .checking
    @State private var checkTimer: Timer?
    
    var body: some View {
        HStack(spacing: 16) {
            // Local Server Status
            HStack(spacing: 8) {
                Circle()
                    .fill(localServerStatus.color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(localServerStatus.color.opacity(0.3), lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: localServerStatus)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Server")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(localServerStatus.message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .frame(height: 20)
            
            // Network Server Status
            HStack(spacing: 8) {
                Circle()
                    .fill(networkServerStatus.color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(networkServerStatus.color.opacity(0.3), lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: networkServerStatus)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network Access")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(networkServerStatus.message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Global URL if available
            if let externalIP = networkManager.externalIPAddress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Global URL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("http://\(externalIP):\(project.port)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            startStatusChecking()
        }
        .onDisappear {
            stopStatusChecking()
        }
        .onChange(of: project.status) { _, newStatus in
            checkServerStatus()
        }
    }
    
    private func startStatusChecking() {
        checkServerStatus()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            checkServerStatus()
        }
    }
    
    private func stopStatusChecking() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func checkServerStatus() {
        // Check local server status
        if project.status == .running {
            // Check if server is actually responding on localhost
            Task {
                let isResponding = await checkPort(port: project.port, host: "localhost")
                await MainActor.run {
                    localServerStatus = isResponding ? .connected : .error
                }
            }
            
            // Check network server status
            Task {
                let isNetworkAccessible = await checkPort(port: project.port, host: networkManager.localIPAddress)
                await MainActor.run {
                    networkServerStatus = isNetworkAccessible ? .connected : .limited
                }
            }
        } else {
            localServerStatus = .disconnected
            networkServerStatus = .disconnected
        }
    }
    
    private func checkPort(port: Int, host: String) async -> Bool {
        // Simple port check - in production, you'd want a more robust check
        return await NetworkManager.shared.scanPort(port, on: host)
    }
}

enum ServerConnectionStatus {
    case checking
    case connected
    case disconnected
    case error
    case limited
    
    var color: Color {
        switch self {
        case .checking:
            return .orange
        case .connected:
            return .green
        case .disconnected:
            return .gray
        case .error:
            return .red
        case .limited:
            return .yellow
        }
    }
    
    var message: String {
        switch self {
        case .checking:
            return "Checking..."
        case .connected:
            return "Connected"
        case .disconnected:
            return "Not running"
        case .error:
            return "Connection failed"
        case .limited:
            return "Local only"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ProjectManager())
}
