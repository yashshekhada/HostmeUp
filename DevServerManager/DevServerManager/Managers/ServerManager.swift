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
        
        // Run all potentially blocking operations on background thread
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    // Use effective execution path instead of project path
                    let executionPath = project.effectiveExecutionPath
                    
                    // Validate project path on background thread
                    guard FileManager.default.fileExists(atPath: executionPath) else {
                        continuation.resume(throwing: ServerError.invalidPath)
                        return
                    }
                    
                    // For .NET applications, we'll let them use their default port if needed
                    // and detect what port they actually bind to
                    
                    // Create process on background thread
                    let process = Process()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    // Configure process
                    process.currentDirectoryPath = executionPath
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    // Use effective start command instead of project startCommand
                    var commandComponents = self.parseCommand(project.effectiveStartCommand)
                    guard let executable = commandComponents.first else {
                        continuation.resume(throwing: ServerError.invalidCommand)
                        return
                    }
                    
                    // For .NET projects, ensure we use the full path to dotnet if needed
                    if (project.type == .dotnet || project.type == .aspnet) && executable == "dotnet" {
                        // Check if dotnet is available in the standard location
                        let dotnetPath = "/usr/local/share/dotnet/dotnet"
                        if FileManager.default.fileExists(atPath: dotnetPath) {
                            commandComponents[0] = dotnetPath
                        } else {
                            // Fallback to system PATH
                            commandComponents[0] = "dotnet"
                        }
                    }
                    
                    // Special handling for .NET applications to ensure correct port
                    if project.type == .dotnet || project.type == .aspnet {
                        // Add port-specific arguments for .NET applications
                        if project.useDLLExecution {
                            // For DLL execution, add --urls parameter with network binding
                            commandComponents.append("--urls")
                            commandComponents.append("http://0.0.0.0:\(project.port);http://localhost:\(project.port);http://127.0.0.1:\(project.port)")
                        } else {
                            // For source code execution, add --urls parameter to dotnet run
                            if commandComponents.contains("run") {
                                commandComponents.append("--urls")
                                commandComponents.append("http://0.0.0.0:\(project.port);http://localhost:\(project.port);http://127.0.0.1:\(project.port)")
                            }
                        }
                    }
                    
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = commandComponents
                    
                    // Setup environment
                    var environment = ProcessInfo.processInfo.environment
                    // Add common development tool paths to PATH
                    let additionalPaths = [
                        "/usr/local/share/dotnet",
                        "/usr/local/bin", 
                        "/usr/bin",
                        "/bin",
                        "/usr/sbin",
                        "/sbin",
                        "/opt/homebrew/bin",
                        "/opt/homebrew/sbin"
                    ]
                    let currentPath = environment["PATH"] ?? ""
                    let newPath = additionalPaths.joined(separator: ":") + ":" + currentPath
                    environment["PATH"] = newPath
                    environment["PORT"] = "\(project.port)"
                    
                    // ASP.NET Core specific environment variables
                    if project.type == .dotnet || project.type == .aspnet {
                        environment["ASPNETCORE_ENVIRONMENT"] = project.buildConfiguration == .debug ? "Development" : "Production"
                        environment["DOTNET_ENVIRONMENT"] = project.buildConfiguration == .debug ? "Development" : "Production"
                        environment["ASPNETCORE_URLS"] = "http://0.0.0.0:\(project.port);http://localhost:\(project.port);http://127.0.0.1:\(project.port)"
                        environment["ASPNETCORE_HTTP_PORT"] = "\(project.port)"
                    }
                    
                    process.environment = environment
                    
                    // Setup output monitoring
                    await MainActor.run {
                        self.setupOutputMonitoring(for: project.id, outputPipe: outputPipe, errorPipe: errorPipe)
                    }
                    
                    // Start process on background thread
                    try process.run()
                    
                    // Store process on main actor
                    await MainActor.run {
                        self.runningProcesses[project.id] = process
                    }
                    
                    // Wait for process to start and check if it's actually listening
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds to let it fully start
                    
                    // Check if process is still running
                    if !process.isRunning {
                        // Process died, check output for error
                        let output = await MainActor.run {
                            self.processOutputs[project.id] ?? ""
                        }
                        print("Process died. Output: \(output)")
                        continuation.resume(throwing: ServerError.failedToStart)
                        return
                    }
                    
                    // Verify the server is actually listening on some port
                    let isListening = await self.checkIfServerIsListening(process: process)
                    if !isListening {
                        print("Process running but not listening on expected port")
                        // Don't fail here - the server might be starting on a different port
                        // which is common with .NET applications
                    }
                    
                    continuation.resume(returning: process.processIdentifier)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
        return await withCheckedContinuation { continuation in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
                task.arguments = ["-i", ":\(port)"]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    // Port is available if lsof returns non-zero (no process found)
                    continuation.resume(returning: task.terminationStatus != 0)
                } catch {
                    // Assume available if we can't check
                    continuation.resume(returning: true)
                }
            }
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
    
    // New method to check if server is actually listening
    private func checkIfServerIsListening(process: Process) async -> Bool {
        // Check if the process is listening on any HTTP port
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        task.arguments = ["-p", "\(process.processIdentifier)", "-i"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Check if output contains any HTTP ports (common web server ports)
            let httpPorts = ["5000", "5001", "3000", "8000", "8080", "4200", "1313", "4000"]
            for port in httpPorts {
                if output.contains(":\(port)") {
                    return true
                }
            }
            
            // Also check for any listening socket
            return task.terminationStatus == 0 && !output.isEmpty
        } catch {
            // If lsof fails, assume the process is running correctly
            return process.isRunning
        }
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