import Foundation
import SwiftUI
import Combine

// MARK: - Data Models

struct Project: Identifiable, Codable {
    let id = UUID()
    var name: String
    var path: String
    var type: ProjectType
    var port: Int
    var startCommand: String
    var status: ProjectStatus = .stopped
    var processId: Int32? = nil
    var externalURL: String? = nil
    var prerequisites: [String] = []
    var lastStarted: Date? = nil
    var lastStopped: Date? = nil
    
    init(name: String, path: String, type: ProjectType, port: Int, startCommand: String) {
        self.name = name
        self.path = path
        self.type = type
        self.port = port
        self.startCommand = startCommand
        self.prerequisites = type.prerequisites
    }
}

enum ProjectType: String, CaseIterable, Codable {
    case nodejs = "Node.js"
    case react = "React"
    case vue = "Vue.js"
    case angular = "Angular"
    case nextjs = "Next.js"
    case nuxt = "Nuxt.js"
    case dotnet = ".NET"
    case aspnet = "ASP.NET"
    case python = "Python"
    case flask = "Flask"
    case django = "Django"
    case fastapi = "FastAPI"
    case ruby = "Ruby"
    case rails = "Rails"
    case php = "PHP"
    case laravel = "Laravel"
    case go = "Go"
    case rust = "Rust"
    case java = "Java"
    case spring = "Spring Boot"
    case static = "Static Site"
    case gatsby = "Gatsby"
    case hugo = "Hugo"
    case jekyll = "Jekyll"
    
    var icon: String {
        switch self {
        case .nodejs, .react, .vue, .angular, .nextjs, .nuxt:
            return "gear"
        case .dotnet, .aspnet:
            return "square.stack.3d.down.right"
        case .python, .flask, .django, .fastapi:
            return "snake"
        case .ruby, .rails:
            return "gem"
        case .php, .laravel:
            return "globe"
        case .go, .rust:
            return "speedometer"
        case .java, .spring:
            return "cup.and.saucer"
        case .static, .gatsby, .hugo, .jekyll:
            return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .nodejs, .vue:
            return .green
        case .react, .nextjs:
            return .blue
        case .angular:
            return .red
        case .dotnet, .aspnet:
            return .purple
        case .python, .flask, .django, .fastapi:
            return .yellow
        case .ruby, .rails:
            return .red
        case .php, .laravel:
            return .indigo
        case .go:
            return .cyan
        case .rust:
            return .orange
        case .java, .spring:
            return .brown
        case .static, .gatsby, .hugo, .jekyll:
            return .gray
        case .nuxt:
            return .green
        }
    }
    
    var prerequisites: [String] {
        switch self {
        case .nodejs, .react, .vue, .angular, .nextjs, .nuxt:
            return ["Node.js", "npm"]
        case .dotnet, .aspnet:
            return [".NET SDK"]
        case .python, .flask, .django, .fastapi:
            return ["Python", "pip"]
        case .ruby, .rails:
            return ["Ruby", "gem"]
        case .php, .laravel:
            return ["PHP", "Composer"]
        case .go:
            return ["Go"]
        case .rust:
            return ["Rust", "Cargo"]
        case .java, .spring:
            return ["Java", "Maven/Gradle"]
        case .static, .gatsby, .hugo, .jekyll:
            return []
        }
    }
    
    var defaultStartCommand: String {
        switch self {
        case .nodejs:
            return "npm start"
        case .react:
            return "npm start"
        case .vue:
            return "npm run serve"
        case .angular:
            return "ng serve"
        case .nextjs:
            return "npm run dev"
        case .nuxt:
            return "npm run dev"
        case .dotnet:
            return "dotnet run"
        case .aspnet:
            return "dotnet run"
        case .python:
            return "python app.py"
        case .flask:
            return "flask run"
        case .django:
            return "python manage.py runserver"
        case .fastapi:
            return "uvicorn main:app --reload"
        case .ruby:
            return "ruby app.rb"
        case .rails:
            return "rails server"
        case .php:
            return "php -S localhost:8000"
        case .laravel:
            return "php artisan serve"
        case .go:
            return "go run main.go"
        case .rust:
            return "cargo run"
        case .java:
            return "java -jar app.jar"
        case .spring:
            return "mvn spring-boot:run"
        case .static:
            return "python -m http.server"
        case .gatsby:
            return "gatsby develop"
        case .hugo:
            return "hugo server"
        case .jekyll:
            return "bundle exec jekyll serve"
        }
    }
}

enum ProjectStatus: String, Codable {
    case stopped = "stopped"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case error = "error"
}

// MARK: - Optimized ProjectManager

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    
    // Performance optimizations
    private var projectsDict: [UUID: Project] = [:]
    private var projectsByPort: [Int: UUID] = [:]
    private var projectsByPath: [String: UUID] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "SavedProjects"
    
    // Dependencies
    private let serverManager = ServerManager()
    private let networkManager = NetworkManager.shared
    private let portForwardingManager = PortForwardingManager.shared
    
    // Performance optimization: Debouncing and caching
    private var cancellables = Set<AnyCancellable>()
    private let saveSubject = PassthroughSubject<Void, Never>()
    private let fileQueue = DispatchQueue(label: "ProjectFileManager", qos: .utility)
    
    // Status monitoring
    private var statusUpdateTimer: Timer?
    private let statusUpdateInterval: TimeInterval = 2.0
    
    init() {
        setupDebouncedSave()
        loadProjects()
        setupStatusMonitoring()
    }
    
    deinit {
        cancellables.removeAll()
        statusUpdateTimer?.invalidate()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupDebouncedSave() {
        saveSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveProjectsAsync()
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusMonitoring() {
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateRunningProjectsStatus()
        }
    }
    
    // MARK: - Project Management
    
    func addProject(_ project: Project) {
        let optimizedProject = Project(
            name: project.name,
            path: project.path,
            type: project.type,
            port: findAvailablePort(startingFrom: project.port),
            startCommand: project.startCommand.isEmpty ? project.type.defaultStartCommand : project.startCommand
        )
        
        projects.append(optimizedProject)
        updateIndices(for: optimizedProject)
        triggerSave()
    }
    
    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Remove from old indices
        removeFromIndices(projects[index])
        
        // Update project
        projects[index] = project
        
        // Update indices
        updateIndices(for: project)
        triggerSave()
    }
    
    func deleteProject(_ project: Project) {
        // Stop server if running
        if project.status == .running {
            stopServer(for: project)
        }
        
        // Remove from arrays and indices
        projects.removeAll { $0.id == project.id }
        removeFromIndices(project)
        triggerSave()
    }
    
    func getProject(by id: UUID) -> Project? {
        return projectsDict[id]
    }
    
    func getProject(by port: Int) -> Project? {
        guard let id = projectsByPort[port] else { return nil }
        return projectsDict[id]
    }
    
    func getProject(by path: String) -> Project? {
        guard let id = projectsByPath[path] else { return nil }
        return projectsDict[id]
    }
    
    func getRunningProjects() -> [Project] {
        return projects.filter { $0.status == .running }
    }
    
    // MARK: - Server Management
    
    func startServer(for project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        projects[index].status = .starting
        updateIndices(for: projects[index])
        
        Task {
            do {
                let processId = try await serverManager.startServer(for: projects[index])
                
                await MainActor.run {
                    if let currentIndex = self.projects.firstIndex(where: { $0.id == project.id }) {
                        self.projects[currentIndex].processId = processId
                        self.projects[currentIndex].status = .running
                        self.projects[currentIndex].lastStarted = Date()
                        
                        // Setup port forwarding
                        self.setupPortForwardingForProject(self.projects[currentIndex])
                        self.updateIndices(for: self.projects[currentIndex])
                    }
                }
            } catch {
                await MainActor.run {
                    if let currentIndex = self.projects.firstIndex(where: { $0.id == project.id }) {
                        self.projects[currentIndex].status = .error
                        self.updateIndices(for: self.projects[currentIndex])
                    }
                }
            }
        }
    }
    
    func stopServer(for project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        projects[index].status = .stopping
        updateIndices(for: projects[index])
        
        Task {
            do {
                try await serverManager.stopServer(for: projects[index])
                
                await MainActor.run {
                    if let currentIndex = self.projects.firstIndex(where: { $0.id == project.id }) {
                        self.projects[currentIndex].processId = nil
                        self.projects[currentIndex].status = .stopped
                        self.projects[currentIndex].lastStopped = Date()
                        
                        // Remove port forwarding
                        self.portForwardingManager.removePortForwarding(for: self.projects[currentIndex].port)
                        self.updateIndices(for: self.projects[currentIndex])
                    }
                }
            } catch {
                await MainActor.run {
                    if let currentIndex = self.projects.firstIndex(where: { $0.id == project.id }) {
                        self.projects[currentIndex].status = .error
                        self.updateIndices(for: self.projects[currentIndex])
                    }
                }
            }
        }
    }
    
    func restartServer(for project: Project) {
        stopServer(for: project)
        
        // Use async delay instead of DispatchQueue
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                self.startServer(for: project)
            }
        }
    }
    
    // MARK: - Port Management
    
    private func findAvailablePort(startingFrom port: Int) -> Int {
        var currentPort = port
        
        while currentPort <= 3300 {
            if projectsByPort[currentPort] == nil {
                return currentPort
            }
            currentPort += 1
        }
        
        return port // fallback
    }
    
    private func setupPortForwardingForProject(_ project: Project) {
        portForwardingManager.setupPortForwarding(for: project.port)
        
        // Update external URL if available
        if let externalIP = networkManager.externalIPAddress {
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].externalURL = "http://\(externalIP):\(project.port)"
                updateIndices(for: projects[index])
            }
        }
    }
    
    // MARK: - Status Monitoring
    
    private func updateRunningProjectsStatus() {
        let runningProjects = getRunningProjects()
        
        Task {
            for project in runningProjects {
                await checkProjectStatus(project)
            }
        }
    }
    
    private func checkProjectStatus(_ project: Project) async {
        guard let processId = project.processId else { return }
        
        // Check if process is still running
        let isRunning = kill(processId, 0) == 0
        
        await MainActor.run {
            if !isRunning {
                if let index = self.projects.firstIndex(where: { $0.id == project.id }) {
                    self.projects[index].status = .stopped
                    self.projects[index].processId = nil
                    self.projects[index].lastStopped = Date()
                    self.updateIndices(for: self.projects[index])
                }
            }
        }
    }
    
    // MARK: - Index Management
    
    private func updateIndices(for project: Project) {
        projectsDict[project.id] = project
        projectsByPort[project.port] = project.id
        projectsByPath[project.path] = project.id
    }
    
    private func removeFromIndices(_ project: Project) {
        projectsDict.removeValue(forKey: project.id)
        projectsByPort.removeValue(forKey: project.port)
        projectsByPath.removeValue(forKey: project.path)
    }
    
    private func rebuildIndices() {
        projectsDict.removeAll()
        projectsByPort.removeAll()
        projectsByPath.removeAll()
        
        for project in projects {
            updateIndices(for: project)
        }
    }
    
    // MARK: - Persistence
    
    private func triggerSave() {
        saveSubject.send()
    }
    
    private func saveProjectsAsync() {
        Task {
            await saveProjects()
        }
    }
    
    private func saveProjects() async {
        let projectsToSave = await MainActor.run { projects }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let data = try JSONEncoder().encode(projectsToSave)
                    await MainActor.run {
                        self.userDefaults.set(data, forKey: self.projectsKey)
                    }
                } catch {
                    print("Failed to save projects: \(error)")
                }
            }
        }
    }
    
    private func loadProjects() {
        Task {
            await loadProjectsAsync()
        }
    }
    
    private func loadProjectsAsync() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard let data = await MainActor.run({ self.userDefaults.data(forKey: self.projectsKey) }) else { return }
                
                do {
                    let loadedProjects = try JSONDecoder().decode([Project].self, from: data)
                    await MainActor.run {
                        self.projects = loadedProjects
                        self.rebuildIndices()
                    }
                } catch {
                    print("Failed to load projects: \(error)")
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    func validateProjectPath(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    func detectProjectType(at path: String) -> ProjectType? {
        let fileManager = FileManager.default
        
        // Check for specific files that indicate project type
        if fileManager.fileExists(atPath: "\(path)/package.json") {
            if fileManager.fileExists(atPath: "\(path)/next.config.js") {
                return .nextjs
            } else if fileManager.fileExists(atPath: "\(path)/nuxt.config.js") {
                return .nuxt
            } else if fileManager.fileExists(atPath: "\(path)/angular.json") {
                return .angular
            } else if fileManager.fileExists(atPath: "\(path)/vue.config.js") {
                return .vue
            }
            return .nodejs
        }
        
        if fileManager.fileExists(atPath: "\(path)/requirements.txt") || fileManager.fileExists(atPath: "\(path)/setup.py") {
            return .python
        }
        
        if fileManager.fileExists(atPath: "\(path)/Gemfile") {
            return .ruby
        }
        
        if fileManager.fileExists(atPath: "\(path)/composer.json") {
            return .php
        }
        
        if fileManager.fileExists(atPath: "\(path)/go.mod") {
            return .go
        }
        
        if fileManager.fileExists(atPath: "\(path)/Cargo.toml") {
            return .rust
        }
        
        if fileManager.fileExists(atPath: "\(path)/pom.xml") || fileManager.fileExists(atPath: "\(path)/build.gradle") {
            return .java
        }
        
        if fileManager.fileExists(atPath: "\(path)/*.csproj") || fileManager.fileExists(atPath: "\(path)/*.sln") {
            return .dotnet
        }
        
        return nil
    }
}

// MARK: - Extensions

extension ProjectManager {
    var totalProjects: Int {
        projects.count
    }
    
    var runningProjectsCount: Int {
        projects.lazy.filter { $0.status == .running }.count
    }
    
    var stoppedProjectsCount: Int {
        projects.lazy.filter { $0.status == .stopped }.count
    }
    
    var errorProjectsCount: Int {
        projects.lazy.filter { $0.status == .error }.count
    }
}