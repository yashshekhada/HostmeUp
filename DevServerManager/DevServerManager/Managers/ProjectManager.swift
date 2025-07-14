import Foundation
import SwiftUI

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
    
    var defaultCommand: String {
        switch self {
        case .nodejs:
            return "node index.js"
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
    
    var prerequisites: [String] {
        switch self {
        case .nodejs, .react, .vue, .angular, .nextjs, .nuxt, .gatsby:
            return ["Node.js", "npm"]
        case .dotnet, .aspnet:
            return [".NET SDK"]
        case .python, .flask, .django, .fastapi:
            return ["Python 3.x", "pip"]
        case .ruby, .rails:
            return ["Ruby", "gem"]
        case .php, .laravel:
            return ["PHP", "Composer"]
        case .go:
            return ["Go"]
        case .rust:
            return ["Rust", "Cargo"]
        case .java, .spring:
            return ["Java JDK", "Maven/Gradle"]
        case .static:
            return ["Web Server"]
        case .hugo:
            return ["Hugo"]
        case .jekyll:
            return ["Ruby", "Jekyll"]
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .nodejs, .react, .nextjs, .nuxt, .gatsby:
            return 3000
        case .vue:
            return 8080
        case .angular:
            return 4200
        case .dotnet, .aspnet:
            return 5000
        case .python, .flask, .fastapi:
            return 5000
        case .django:
            return 8000
        case .ruby, .rails:
            return 3000
        case .php, .laravel:
            return 8000
        case .go:
            return 8080
        case .rust:
            return 8000
        case .java, .spring:
            return 8080
        case .static:
            return 8000
        case .hugo:
            return 1313
        case .jekyll:
            return 4000
        }
    }
}

enum ProjectStatus: String, Codable {
    case stopped = "Stopped"
    case starting = "Starting"
    case running = "Running"
    case stopping = "Stopping"
    case error = "Error"
    
    var color: Color {
        switch self {
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
}

// MARK: - Project Manager

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    private let serverManager = ServerManager()
    private let portForwardingManager = PortForwardingManager()
    private let networkManager = NetworkManager.shared
    
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "SavedProjects"
    
    init() {
        loadProjects()
        setupPortForwarding()
    }
    
    // MARK: - Project Management
    
    func addProject(_ project: Project) {
        var newProject = project
        
        // Ensure unique port
        if projects.contains(where: { $0.port == project.port }) {
            newProject.port = findAvailablePort(startingFrom: project.port)
        }
        
        projects.append(newProject)
        saveProjects()
    }
    
    func deleteProject(_ project: Project) {
        if project.status == .running {
            stopServer(for: project)
        }
        
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
        }
    }
    
    // MARK: - Server Management
    
    func startServer(for project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        projects[index].status = .starting
        
        Task {
            do {
                let processId = try await serverManager.startServer(for: projects[index])
                
                await MainActor.run {
                    projects[index].processId = processId
                    projects[index].status = .running
                    projects[index].lastStarted = Date()
                    
                    // Setup port forwarding
                    setupPortForwardingForProject(projects[index])
                }
            } catch {
                await MainActor.run {
                    projects[index].status = .error
                }
            }
        }
    }
    
    func stopServer(for project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        projects[index].status = .stopping
        
        Task {
            do {
                try await serverManager.stopServer(for: projects[index])
                
                await MainActor.run {
                    projects[index].processId = nil
                    projects[index].status = .stopped
                    projects[index].lastStopped = Date()
                    
                    // Remove port forwarding
                    portForwardingManager.removePortForwarding(for: projects[index].port)
                }
            } catch {
                await MainActor.run {
                    projects[index].status = .error
                }
            }
        }
    }
    
    func restartServer(for project: Project) {
        stopServer(for: project)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.startServer(for: project)
        }
    }
    
    // MARK: - Port Management
    
    private func findAvailablePort(startingFrom port: Int) -> Int {
        var currentPort = port
        
        while currentPort <= 3300 {
            if !projects.contains(where: { $0.port == currentPort }) {
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
            }
        }
    }
    
    private func setupPortForwarding() {
        // Setup initial port forwarding configuration
        portForwardingManager.configureFirewall()
    }
    
    // MARK: - Persistence
    
    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            userDefaults.set(data, forKey: projectsKey)
        } catch {
            print("Failed to save projects: \(error)")
        }
    }
    
    private func loadProjects() {
        guard let data = userDefaults.data(forKey: projectsKey) else { return }
        
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            print("Failed to load projects: \(error)")
        }
    }
}