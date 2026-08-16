import Foundation

enum SystemHealthLevel: Int, Comparable, Sendable {
    case collecting
    case partial
    case stale
    case healthy
    case elevated
    case critical

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct SystemHealthAssessment: Equatable, Sendable {
    let level: SystemHealthLevel
    let title: String
    let evidence: String
    let recommendation: String
    let destination: AppSection
}

enum SystemHealthAnalyzer {
    static func assess(
        memoryPressure: MemoryStats.Pressure?,
        memoryTimestamp: Date?,
        cpuHistory: [CPUStats],
        diskUsedFraction: Double?,
        diskTimestamp: Date?,
        thermalState: ThermalStats.State?,
        thermalTimestamp: Date?,
        topMemoryProcess: ProcessSnapshot?,
        topCPUProcess: ProcessSnapshot?,
        now: Date = Date()
    ) -> SystemHealthAssessment {
        let memoryAvailable = memoryPressure != nil && memoryPressure != .unavailable
        let currentCPU = cpuHistory.last
        let availableCount = [memoryAvailable, currentCPU != nil, diskUsedFraction != nil, thermalState != nil]
            .filter { $0 }.count
        guard availableCount > 0 else {
            return issue(.collecting, "Collecting system evidence", "No current health signals are available yet.",
                         "Wait for the first memory, CPU, storage, and thermal samples.", .dashboard)
        }
        let timestamps = [
            memoryAvailable ? memoryTimestamp : nil,
            currentCPU?.timestamp,
            diskUsedFraction == nil ? nil : diskTimestamp,
            thermalState == nil ? nil : thermalTimestamp
        ].compactMap { $0 }
        if timestamps.contains(where: { now.timeIntervalSince($0) > 15 }) {
            return issue(.stale, "Some monitoring data is stale", "At least one health signal is more than 15 seconds old.",
                         "Review collector health before trusting a recommendation.", .applications)
        }
        if memoryPressure == .critical {
            return issue(.critical, "Memory pressure is critical", "macOS reports severe memory demand.",
                         "Save your work, then review high-memory applications.", .performance)
        }
        if thermalState == .critical || thermalState == .serious {
            return issue(.critical, "Thermal pressure is high", "macOS is limiting performance to control temperature.",
                         "Reduce sustained CPU or GPU workloads and improve airflow.", .performance)
        }
        if let diskUsedFraction, diskUsedFraction >= 0.98 {
            return issue(.critical, "Startup disk is nearly full", "Less than 2% of startup-disk capacity remains.",
                         "Review the largest files and move unneeded items to Trash.", .disk)
        }
        if memoryPressure == .warning {
            let contributor = topMemoryProcess.map { " \($0.name) currently uses the most visible resident memory." } ?? ""
            return issue(.elevated, "Memory demand is elevated", "macOS reports warning-level pressure.\(contributor)",
                         "Review applications you recognize before ending anything.", .applications)
        }
        if sustainedHighCPU(cpuHistory, now: now) {
            let contributor = topCPUProcess.map { " \($0.name) is the current top CPU process." } ?? ""
            return issue(.elevated, "CPU usage is persistently high", "Average CPU usage stayed above 90% for at least 15 seconds.\(contributor)",
                         "Check whether the workload is expected before taking action.", .applications)
        }
        if let diskUsedFraction, diskUsedFraction >= 0.90 {
            return issue(.elevated, "Startup disk space is low", "More than 90% of startup-disk capacity is used.",
                         "Review storage usage before free space becomes critical.", .disk)
        }
        if availableCount < 3 {
            return issue(.partial, "Only partial evidence is available", "MacScope has \(availableCount) of 4 primary health signals.",
                         "No overall health claim will be made until more collectors report current data.", .applications)
        }
        return issue(.healthy, "No immediate problem detected", "Current public pressure signals are within normal limits.",
                     "No action is recommended. Continue monitoring if the Mac still feels slow.", .events)
    }

    static func sustainedHighCPU(_ history: [CPUStats], now: Date) -> Bool {
        let recent = history.filter { now.timeIntervalSince($0.timestamp) >= 0 && now.timeIntervalSince($0.timestamp) <= 20 }
        guard let first = recent.first, let last = recent.last,
              last.timestamp.timeIntervalSince(first.timestamp) >= 15 else { return false }
        return recent.reduce(0) { $0 + $1.totalUsage } / Double(recent.count) >= 0.90
    }

    private static func issue(
        _ level: SystemHealthLevel, _ title: String, _ evidence: String,
        _ recommendation: String, _ destination: AppSection
    ) -> SystemHealthAssessment {
        .init(level: level, title: title, evidence: evidence, recommendation: recommendation, destination: destination)
    }
}
