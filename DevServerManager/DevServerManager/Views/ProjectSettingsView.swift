import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.dismiss) var dismiss
    
    @State private var project: Project
    @State private var isEditing = false
    
    init(project: Project) {
        self._project = State(initialValue: project)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Information") {
                    TextField("Project Name", text: $project.name)
                        .disabled(!isEditing)
                    
                    HStack {
                        TextField("Project Path", text: $project.path)
                            .disabled(!isEditing)
                        
                        if isEditing {
                            Button("Browse") {
                                selectProjectPath()
                            }
                        }
                    }
                    
                    Picker("Project Type", selection: $project.type) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .disabled(!isEditing)
                    
                    TextField("Port", value: $project.port, format: .number)
                        .disabled(!isEditing)
                    
                    TextField("Start Command", text: $project.startCommand)
                        .disabled(!isEditing)
                }
                
                Section("Network Settings") {
                    TextField("External URL", text: Binding(
                        get: { project.externalURL ?? "" },
                        set: { project.externalURL = $0.isEmpty ? nil : $0 }
                    ))
                    .disabled(!isEditing)
                    
                    Toggle("Enable External Access", isOn: Binding(
                        get: { project.externalURL != nil },
                        set: { enabled in
                            if enabled {
                                project.externalURL = "http://\(NetworkManager.shared.externalIPAddress ?? "external-ip"):\(project.port)"
                            } else {
                                project.externalURL = nil
                            }
                        }
                    ))
                    .disabled(!isEditing)
                }
                
                Section("Prerequisites") {
                    ForEach(project.prerequisites, id: \.self) { prerequisite in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(prerequisite)
                        }
                    }
                }
                
                if project.status == .running {
                    Section("Runtime Information") {
                        HStack {
                            Text("Status")
                            Spacer()
                            StatusIndicator(status: project.status)
                        }
                        
                        if let processId = project.processId {
                            HStack {
                                Text("Process ID")
                                Spacer()
                                Text("\(processId)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let startTime = project.lastStarted {
                            HStack {
                                Text("Started")
                                Spacer()
                                Text(startTime, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                    }
                    
                    Button("Open in Terminal") {
                        openInTerminal()
                    }
                    
                    Button("Copy Local URL") {
                        NSPasteboard.general.setString("http://localhost:\(project.port)", forType: .string)
                    }
                    
                    if let externalURL = project.externalURL {
                        Button("Copy External URL") {
                            NSPasteboard.general.setString(externalURL, forType: .string)
                        }
                    }
                }
            }
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            projectManager.updateProject(project)
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func selectProjectPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK {
            project.path = panel.url?.path ?? ""
        }
    }
    
    private func openInTerminal() {
        let script = """
            tell application "Terminal"
                do script "cd '\(project.path)'"
                activate
            end tell
            """
        
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }
}

#Preview {
    ProjectSettingsView(project: Project(
        name: "Sample Project",
        path: "/Users/username/projects/sample",
        type: .nodejs,
        port: 3000,
        startCommand: "npm start"
    ))
    .environmentObject(ProjectManager())
}