import Foundation

enum SystemHealthLevel: Int, Comparable, Sendable {
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
        cpuUsage: Double?,
        diskUsedFraction: Double?,
        thermalState: ThermalStats.State?,
        topMemoryProcess: ProcessSnapshot?,
        topCPUProcess: ProcessSnapshot?
    ) -> SystemHealthAssessment {
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
        if let cpuUsage, cpuUsage >= 0.90 {
            let contributor = topCPUProcess.map { " \($0.name) is the current top CPU process." } ?? ""
            return issue(.elevated, "CPU usage is high", "Total CPU usage is above 90%.\(contributor)",
                         "Check whether the workload is expected before taking action.", .applications)
        }
        if let diskUsedFraction, diskUsedFraction >= 0.90 {
            return issue(.elevated, "Startup disk space is low", "More than 90% of startup-disk capacity is used.",
                         "Review storage usage before free space becomes critical.", .disk)
        }
        return issue(.healthy, "No immediate problem detected", "Current public pressure signals are within normal limits.",
                     "No action is recommended. Continue monitoring if the Mac still feels slow.", .events)
    }

    private static func issue(
        _ level: SystemHealthLevel, _ title: String, _ evidence: String,
        _ recommendation: String, _ destination: AppSection
    ) -> SystemHealthAssessment {
        .init(level: level, title: title, evidence: evidence, recommendation: recommendation, destination: destination)
    }
}
