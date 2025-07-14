import Foundation
import SwiftUI
import Combine

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    @Published var cpuUsage: Double = 0.0
    @Published var networkLatency: Double = 0.0
    @Published var activeTimers: Int = 0
    @Published var activeConnections: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 3.0
    
    // Performance metrics
    private var startTime: Date = Date()
    private var lastCPUInfo: host_cpu_load_info_data_t?
    private var performanceMetrics: [PerformanceMetric] = []
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        
        startTime = Date()
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Metrics Collection
    
    private func updateMetrics() {
        Task {
            await updateMemoryUsage()
            await updateCPUUsage()
            await updateNetworkLatency()
            
            // Log performance metrics
            let metric = PerformanceMetric(
                timestamp: Date(),
                memoryUsage: memoryUsage,
                cpuUsage: cpuUsage,
                networkLatency: networkLatency
            )
            
            await MainActor.run {
                self.performanceMetrics.append(metric)
                
                // Keep only last 100 metrics
                if self.performanceMetrics.count > 100 {
                    self.performanceMetrics.removeFirst()
                }
            }
        }
    }
    
    private func updateMemoryUsage() async {
        let usage = getMemoryUsage()
        await MainActor.run {
            self.memoryUsage = usage
        }
    }
    
    private func updateCPUUsage() async {
        let usage = getCPUUsage()
        await MainActor.run {
            self.cpuUsage = usage
        }
    }
    
    private func updateNetworkLatency() async {
        let latency = await measureNetworkLatency()
        await MainActor.run {
            self.networkLatency = latency
        }
    }
    
    // MARK: - System Metrics
    
    private func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024 / 1024 // Convert to MB
            let maxMemory = Double(info.virtual_size) / 1024 / 1024 // Convert to MB
            
            return MemoryUsage(
                used: usedMemory,
                available: maxMemory - usedMemory,
                total: maxMemory
            )
        }
        
        return MemoryUsage()
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &cpuInfo,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) {
                Array(UnsafeBufferPointer(start: $0, count: Int(numCpus)))
            }
            
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            var totalNice: UInt32 = 0
            
            for cpu in cpuLoadInfo {
                totalUser += cpu.cpu_ticks.0
                totalSystem += cpu.cpu_ticks.1
                totalIdle += cpu.cpu_ticks.2
                totalNice += cpu.cpu_ticks.3
            }
            
            let totalTicks = totalUser + totalSystem + totalIdle + totalNice
            let usedTicks = totalUser + totalSystem + totalNice
            
            let cpuUsage = Double(usedTicks) / Double(totalTicks) * 100.0
            
            // Deallocate the memory
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
            
            return cpuUsage
        }
        
        return 0.0
    }
    
    private func measureNetworkLatency() async -> Double {
        let startTime = Date()
        
        do {
            // Ping localhost as a simple latency test
            let url = URL(string: "http://127.0.0.1:3000")!
            let (_, _) = try await URLSession.shared.data(from: url)
            
            let endTime = Date()
            return endTime.timeIntervalSince(startTime) * 1000 // Convert to milliseconds
        } catch {
            return 0.0
        }
    }
    
    // MARK: - Performance Analysis
    
    func getPerformanceReport() -> PerformanceReport {
        let uptime = Date().timeIntervalSince(startTime)
        let averageMemoryUsage = performanceMetrics.isEmpty ? 0.0 : performanceMetrics.map { $0.memoryUsage.used }.reduce(0, +) / Double(performanceMetrics.count)
        let averageCPUUsage = performanceMetrics.isEmpty ? 0.0 : performanceMetrics.map { $0.cpuUsage }.reduce(0, +) / Double(performanceMetrics.count)
        let averageNetworkLatency = performanceMetrics.isEmpty ? 0.0 : performanceMetrics.map { $0.networkLatency }.reduce(0, +) / Double(performanceMetrics.count)
        
        return PerformanceReport(
            uptime: uptime,
            currentMemoryUsage: memoryUsage,
            averageMemoryUsage: averageMemoryUsage,
            currentCPUUsage: cpuUsage,
            averageCPUUsage: averageCPUUsage,
            currentNetworkLatency: networkLatency,
            averageNetworkLatency: averageNetworkLatency,
            metricsCount: performanceMetrics.count
        )
    }
    
    func getMemoryTrend() -> [Double] {
        return performanceMetrics.map { $0.memoryUsage.used }
    }
    
    func getCPUTrend() -> [Double] {
        return performanceMetrics.map { $0.cpuUsage }
    }
    
    func clearMetrics() {
        performanceMetrics.removeAll()
        startTime = Date()
    }
    
    // MARK: - Optimization Suggestions
    
    func getOptimizationSuggestions() -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        // Memory usage suggestions
        if memoryUsage.used > 500 { // More than 500MB
            suggestions.append(OptimizationSuggestion(
                type: .memory,
                severity: .high,
                description: "High memory usage detected. Consider reducing cached data or optimizing data structures.",
                recommendation: "Review cached network responses and project indices for memory leaks."
            ))
        }
        
        // CPU usage suggestions
        if cpuUsage > 80 {
            suggestions.append(OptimizationSuggestion(
                type: .cpu,
                severity: .high,
                description: "High CPU usage detected. Consider reducing background tasks or optimizing algorithms.",
                recommendation: "Review timer intervals and background network monitoring."
            ))
        }
        
        // Network latency suggestions
        if networkLatency > 1000 { // More than 1 second
            suggestions.append(OptimizationSuggestion(
                type: .network,
                severity: .medium,
                description: "High network latency detected. Consider caching or reducing network requests.",
                recommendation: "Implement request debouncing and cache external IP addresses."
            ))
        }
        
        return suggestions
    }
}

// MARK: - Data Models

struct MemoryUsage {
    let used: Double
    let available: Double
    let total: Double
    
    init(used: Double = 0, available: Double = 0, total: Double = 0) {
        self.used = used
        self.available = available
        self.total = total
    }
    
    var usagePercentage: Double {
        total > 0 ? (used / total) * 100 : 0
    }
}

struct PerformanceMetric {
    let timestamp: Date
    let memoryUsage: MemoryUsage
    let cpuUsage: Double
    let networkLatency: Double
}

struct PerformanceReport {
    let uptime: TimeInterval
    let currentMemoryUsage: MemoryUsage
    let averageMemoryUsage: Double
    let currentCPUUsage: Double
    let averageCPUUsage: Double
    let currentNetworkLatency: Double
    let averageNetworkLatency: Double
    let metricsCount: Int
    
    var uptimeFormatted: String {
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) % 3600 / 60
        let seconds = Int(uptime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct OptimizationSuggestion {
    let type: OptimizationType
    let severity: SeverityLevel
    let description: String
    let recommendation: String
}

enum OptimizationType {
    case memory
    case cpu
    case network
    case storage
    case ui
}

enum SeverityLevel {
    case low
    case medium
    case high
    case critical
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}