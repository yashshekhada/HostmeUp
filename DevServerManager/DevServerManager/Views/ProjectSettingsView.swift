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
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure your project settings")
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
                    // Project Information Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
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
                                    TextField("Project Name", text: $project.name)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!isEditing)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Project Path")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack {
                                        TextField("Project Path", text: $project.path)
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(!isEditing)
                                        
                                        if isEditing {
                                            Button("Browse") {
                                                selectProjectPath()
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Project Type")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Picker("Project Type", selection: $project.type) {
                                        ForEach(ProjectType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(!isEditing)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Port Number")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Port", value: $project.port, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!isEditing)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Command")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Start Command", text: $project.startCommand)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(!isEditing)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // .NET Configuration Card (only show for .NET projects)
                    if project.type == .dotnet || project.type == .aspnet {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "square.stack.3d.down.right")
                                        .foregroundColor(.purple)
                                        .font(.title2)
                                    Text(".NET Configuration")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Build Configuration")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Picker("Build Configuration", selection: $project.buildConfiguration) {
                                            ForEach(BuildConfiguration.allCases, id: \.self) { config in
                                                HStack {
                                                    Image(systemName: config.icon)
                                                        .foregroundColor(config.color)
                                                    VStack(alignment: .leading) {
                                                        Text(config.rawValue)
                                                            .fontWeight(.medium)
                                                        Text(config.description)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }.tag(config)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .disabled(!isEditing)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle("Use DLL Execution (Recommended for Security)", isOn: $project.useDLLExecution)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .disabled(!isEditing)
                                        
                                        Text("Runs from compiled output instead of source code for better security")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if project.useDLLExecution {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Custom DLL Path (Optional)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            TextField("Leave empty to auto-detect", text: Binding(
                                                get: { project.customDLLPath ?? "" },
                                                set: { project.customDLLPath = $0.isEmpty ? nil : $0 }
                                            ))
                                            .textFieldStyle(.roundedBorder)
                                            .disabled(!isEditing)
                                            .help("Leave empty to auto-detect DLL path based on build configuration")
                                        }
                                        
                                        // Show effective paths when editing
                                        if isEditing {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Divider()
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Effective Settings Preview:")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.blue)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Execution Path:")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                        Text(project.effectiveExecutionPath)
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.blue.opacity(0.1))
                                                            .cornerRadius(4)
                                                            .textSelection(.enabled)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Start Command:")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                        Text(project.effectiveStartCommand)
                                                            .font(.caption)
                                                            .foregroundColor(.primary)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.green.opacity(0.1))
                                                            .cornerRadius(4)
                                                            .textSelection(.enabled)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                    
                    // Network Settings Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Network Settings")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("External URL")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("External URL", text: Binding(
                                        get: { project.externalURL ?? "" },
                                        set: { project.externalURL = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(!isEditing)
                                }
                                
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
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // Status Information Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                Text("Status Information")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Current Status")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(project.status.color)
                                            .frame(width: 8, height: 8)
                                        Text(project.status.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(project.status.color)
                                    }
                                }
                                
                                if let processId = project.processId {
                                    HStack {
                                        Text("Process ID")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(processId)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let lastStarted = project.lastStarted {
                                    HStack {
                                        Text("Last Started")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(lastStarted, style: .relative)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // Prerequisites Card
                    if !project.prerequisites.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "checkmark.seal")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    Text("Prerequisites")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
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
                            .padding()
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                    
                    // Actions Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "play.rectangle")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                Text("Actions")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button("Open in Terminal") {
                                        openInTerminal()
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isEditing)
                                    
                                    Button("Open in Finder") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: project.effectiveExecutionPath))
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isEditing)
                                }
                                
                                if project.type == .dotnet || project.type == .aspnet {
                                    Button("Open Source Directory") {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isEditing)
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
                
                Button(isEditing ? "Save Changes" : "Edit Project") {
                    if isEditing {
                        projectManager.updateProject(project)
                    }
                    isEditing.toggle()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 700, height: 700)
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
                do script "cd '\(project.effectiveExecutionPath)'"
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