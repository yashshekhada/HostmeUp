import SwiftUI

struct ContentView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var selectedProject: Project?
    @State private var showingProjectSettings = false
    @State private var showingAddProject = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var filterOption: FilterOption = .all
    
    // Performance optimization: Computed properties with caching
    private var filteredProjects: [Project] {
        var projects = projectManager.projects
        
        // Filter by search text
        if !searchText.isEmpty {
            projects = projects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText) ||
                project.path.localizedCaseInsensitiveContains(searchText) ||
                project.type.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by status
        switch filterOption {
        case .all:
            break
        case .running:
            projects = projects.filter { $0.status == .running }
        case .stopped:
            projects = projects.filter { $0.status == .stopped }
        case .error:
            projects = projects.filter { $0.status == .error }
        }
        
        // Sort projects
        switch sortOption {
        case .name:
            projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .type:
            projects.sort { $0.type.rawValue.localizedCaseInsensitiveCompare($1.type.rawValue) == .orderedAscending }
        case .status:
            projects.sort { $0.status.rawValue.localizedCaseInsensitiveCompare($1.status.rawValue) == .orderedAscending }
        case .lastUsed:
            projects.sort { 
                let date1 = $0.lastStarted ?? Date.distantPast
                let date2 = $1.lastStarted ?? Date.distantPast
                return date1 > date2
            }
        }
        
        return projects
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Project List
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 8) {
                    SearchBar(text: $searchText)
                    
                    FilterControls(
                        sortOption: $sortOption,
                        filterOption: $filterOption
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // Projects List
                if filteredProjects.isEmpty {
                    EmptyStateView(
                        showingAddProject: $showingAddProject,
                        hasProjects: !projectManager.projects.isEmpty
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProjects, id: \.id) { project in
                            OptimizedProjectRowView(
                                project: project,
                                selectedProject: $selectedProject,
                                showingProjectSettings: $showingProjectSettings
                            )
                            .id(project.id)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: filteredProjects.map { $0.id })
                }
                
                Spacer()
            }
            .navigationTitle("Projects (\(filteredProjects.count))")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddProject = true
                    } label: {
                        Label("Add Project", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        } detail: {
            DetailView(selectedProject: selectedProject)
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

// MARK: - Optimized Components

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search projects...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.textBackgroundColor))
        .cornerRadius(6)
    }
}

struct FilterControls: View {
    @Binding var sortOption: SortOption
    @Binding var filterOption: FilterOption
    
    var body: some View {
        HStack {
            // Sort Menu
            Menu {
                Button("Name") { sortOption = .name }
                Button("Type") { sortOption = .type }
                Button("Status") { sortOption = .status }
                Button("Last Used") { sortOption = .lastUsed }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            // Filter Menu
            Menu {
                Button("All") { filterOption = .all }
                Button("Running") { filterOption = .running }
                Button("Stopped") { filterOption = .stopped }
                Button("Error") { filterOption = .error }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
    }
}

struct OptimizedProjectRowView: View {
    let project: Project
    @Binding var selectedProject: Project?
    @Binding var showingProjectSettings: Bool
    @EnvironmentObject var projectManager: ProjectManager
    
    // Memoized properties for performance
    private var isSelected: Bool {
        selectedProject?.id == project.id
    }
    
    private var statusColor: Color {
        switch project.status {
        case .stopped:
            return .gray
        case .starting:
            return .orange
        case .running:
            return .green
        case .stopping:
            return .orange
        case .error:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Project Type Icon
            Image(systemName: project.type.icon)
                .font(.title2)
                .foregroundColor(project.type.color)
                .frame(width: 24, height: 24)
            
            // Project Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(project.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Port: \(project.port)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    if project.status == .running, let pid = project.processId {
                        Text("PID: \(pid)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status and Controls
            VStack(alignment: .trailing, spacing: 4) {
                StatusIndicator(status: project.status, color: statusColor)
                
                QuickActionButtons(project: project)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedProject = project
        }
        .contextMenu {
            ContextMenuItems(
                project: project,
                selectedProject: $selectedProject,
                showingProjectSettings: $showingProjectSettings
            )
        }
    }
}

struct StatusIndicator: View {
    let status: ProjectStatus
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(status.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct QuickActionButtons: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        HStack(spacing: 4) {
            if project.status == .running {
                Button {
                    projectManager.stopServer(for: project)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Stop Server")
            } else if project.status == .stopped {
                Button {
                    projectManager.startServer(for: project)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Start Server")
            }
            
            if project.status == .running || project.status == .stopped {
                Button {
                    projectManager.restartServer(for: project)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Restart Server")
            }
        }
    }
}

struct ContextMenuItems: View {
    let project: Project
    @Binding var selectedProject: Project?
    @Binding var showingProjectSettings: Bool
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        Group {
            Button("Edit") {
                selectedProject = project
                showingProjectSettings = true
            }
            
            Button("Delete") {
                projectManager.deleteProject(project)
            }
            
            Divider()
            
            Button("Open in Finder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
            }
            
            if let url = project.externalURL {
                Button("Open in Browser") {
                    NSWorkspace.shared.open(URL(string: url)!)
                }
            }
            
            Button("Copy Port") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(project.port)", forType: .string)
            }
        }
    }
}

struct EmptyStateView: View {
    @Binding var showingAddProject: Bool
    let hasProjects: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasProjects ? "magnifyingglass" : "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(hasProjects ? "No projects match your search" : "No projects yet")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(hasProjects ? "Try adjusting your search or filter options" : "Add your first project to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !hasProjects {
                Button("Add Project") {
                    showingAddProject = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DetailView: View {
    let selectedProject: Project?
    
    var body: some View {
        if let project = selectedProject {
            ProjectDetailView(project: project)
        } else {
            EmptyDetailView()
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Select a project to view details")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Choose a project from the sidebar to see its details and manage its server")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Supporting Types

enum SortOption: String, CaseIterable {
    case name = "Name"
    case type = "Type"
    case status = "Status"
    case lastUsed = "Last Used"
}

enum FilterOption: String, CaseIterable {
    case all = "All"
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ProjectManager())
}