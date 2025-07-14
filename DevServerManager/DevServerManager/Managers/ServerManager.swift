import Foundation
import Combine

class ServerManager: ObservableObject {
    private var runningProcesses: [UUID: Process] = [:]
    private var processOutputs: [UUID: String] = [:]
    
    // MARK: - Server Management
    
    func startServer(for project: Project) async throws -> Int32 {
        // Check if server is already running
        if let existingProcess = runningProcesses[project.id], existingProcess.isRunning {
            return existingProcess.processIdentifier
        }
        
        // Validate project path
        guard FileManager.default.fileExists(atPath: project.path) else {
            throw ServerError.invalidPath
        }
        
        // Check if port is available
        guard await isPortAvailable(project.port) else {
            throw ServerError.portInUse
        }
        
        // Create process
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Configure process
        process.currentDirectoryPath = project.path
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Parse command
        let commandComponents = parseCommand(project.startCommand)
        guard let executable = commandComponents.first else {
            throw ServerError.invalidCommand
        }
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = commandComponents
        
        // Setup environment
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PORT"] = "\(project.port)"
        process.environment = environment
        
        // Setup output monitoring
        setupOutputMonitoring(for: project.id, outputPipe: outputPipe, errorPipe: errorPipe)
        
        // Start process
        try process.run()
        
        // Store process
        runningProcesses[project.id] = process
        
        // Wait a moment to ensure process started successfully
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if !process.isRunning {
            throw ServerError.failedToStart
        }
        
        return process.processIdentifier
    }
    
    func stopServer(for project: Project) async throws {
        guard let process = runningProcesses[project.id] else {
            throw ServerError.processNotFound
        }
        
        if process.isRunning {
            // Try graceful termination first
            process.terminate()
            
            // Wait for process to terminate
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Force kill if still running
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        // Clean up
        runningProcesses.removeValue(forKey: project.id)
        processOutputs.removeValue(forKey: project.id)
    }
    
    func getServerLogs(for project: Project) -> String {
        return processOutputs[project.id] ?? ""
    }
    
    // MARK: - Helper Methods
    
    private func parseCommand(_ command: String) -> [String] {
        // Simple command parsing - in production, you'd want more sophisticated parsing
        let components = command.components(separatedBy: " ")
        return components.filter { !$0.isEmpty }
    }
    
    private func isPortAvailable(_ port: Int) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        task.arguments = ["-i", ":\(port)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus != 0 // Port is available if lsof returns non-zero
        } catch {
            return true // Assume available if we can't check
        }
    }
    
    private func setupOutputMonitoring(for projectId: UUID, outputPipe: Pipe, errorPipe: Pipe) {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processOutputs[projectId, default: ""] += output
                }
            }
        }
        
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processOutputs[projectId, default: ""] += output
                }
            }
        }
    }
    
    // MARK: - Prerequisites Check
    
    func checkPrerequisites(for project: Project) async -> [PrerequisiteStatus] {
        var results: [PrerequisiteStatus] = []
        
        for prerequisite in project.prerequisites {
            let status = await checkPrerequisite(prerequisite)
            results.append(PrerequisiteStatus(name: prerequisite, isInstalled: status.isInstalled, version: status.version))
        }
        
        return results
    }
    
    private func checkPrerequisite(_ prerequisite: String) async -> (isInstalled: Bool, version: String?) {
        switch prerequisite.lowercased() {
        case "node.js", "nodejs":
            return await checkCommand("node", versionFlag: "--version")
        case "npm":
            return await checkCommand("npm", versionFlag: "--version")
        case "python", "python 3.x":
            return await checkCommand("python3", versionFlag: "--version")
        case "pip":
            return await checkCommand("pip3", versionFlag: "--version")
        case ".net sdk":
            return await checkCommand("dotnet", versionFlag: "--version")
        case "ruby":
            return await checkCommand("ruby", versionFlag: "--version")
        case "gem":
            return await checkCommand("gem", versionFlag: "--version")
        case "php":
            return await checkCommand("php", versionFlag: "--version")
        case "composer":
            return await checkCommand("composer", versionFlag: "--version")
        case "go":
            return await checkCommand("go", versionFlag: "version")
        case "rust":
            return await checkCommand("rustc", versionFlag: "--version")
        case "java jdk":
            return await checkCommand("java", versionFlag: "--version")
        case "maven/gradle":
            let maven = await checkCommand("mvn", versionFlag: "--version")
            let gradle = await checkCommand("gradle", versionFlag: "--version")
            return (maven.isInstalled || gradle.isInstalled, maven.version ?? gradle.version)
        case "hugo":
            return await checkCommand("hugo", versionFlag: "version")
        case "jekyll":
            return await checkCommand("jekyll", versionFlag: "--version")
        default:
            return (false, nil)
        }
    }
    
    private func checkCommand(_ command: String, versionFlag: String) async -> (isInstalled: Bool, version: String?) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [command, versionFlag]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 {
                // Extract version from output
                let version = extractVersion(from: output)
                return (true, version)
            } else {
                return (false, nil)
            }
        } catch {
            return (false, nil)
        }
    }
    
    private func extractVersion(from output: String) -> String? {
        // Simple version extraction - look for patterns like "v1.2.3" or "1.2.3"
        let versionPattern = #"v?(\d+\.\d+(?:\.\d+)?)"#
        let regex = try? NSRegularExpression(pattern: versionPattern, options: [])
        let nsString = output as NSString
        let results = regex?.matches(in: output, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.first {
            return nsString.substring(with: match.range(at: 1))
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct PrerequisiteStatus {
    let name: String
    let isInstalled: Bool
    let version: String?
}

enum ServerError: Error, LocalizedError {
    case invalidPath
    case portInUse
    case invalidCommand
    case failedToStart
    case processNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid project path"
        case .portInUse:
            return "Port is already in use"
        case .invalidCommand:
            return "Invalid start command"
        case .failedToStart:
            return "Failed to start server"
        case .processNotFound:
            return "Process not found"
        }
    }
}