import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var selectedProject: Project?
    @State private var showingProjectSettings = false
    @State private var showingAddProject = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Project List
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
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                VStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a project to view details")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: project.type.icon)
                    .foregroundColor(project.type.color)
                Text(project.name)
                    .font(.headline)
                Spacer()
                StatusIndicator(status: project.status)
            }
            
            Text(project.path)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if project.status == .running {
                HStack {
                    Text("Port: \(project.port)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("PID: \(project.processId ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct StatusIndicator: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(.caption)
                .foregroundColor(status.color)
        }
    }
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
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
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
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
        NavigationView {
            Form {
                Section("Project Information") {
                    TextField("Project Name", text: $name)
                    
                    HStack {
                        TextField("Project Path", text: $path)
                        Button("Browse") {
                            selectProjectPath()
                        }
                    }
                    
                    Picker("Project Type", selection: $type) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Port", value: $port, format: .number)
                    
                    TextField("Start Command", text: $startCommand)
                        .onAppear {
                            startCommand = type.defaultCommand
                        }
                        .onChange(of: type) { newType in
                            startCommand = newType.defaultCommand
                        }
                }
            }
            .navigationTitle("Add Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                    .disabled(name.isEmpty || path.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
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
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    ContentView()
        .environmentObject(ProjectManager())
}