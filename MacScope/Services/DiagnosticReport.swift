import Foundation

struct DiagnosticReportSnapshot: Sendable {
    let appVersion: String
    let appBuild: String
    let systemInfo: SystemInfo?
    let gpuSource: GPUDataSource
    let lifecycle: MonitoringDiagnostics.LifecycleState
    let collectors: [CollectorDiagnostic]
}

enum DiagnosticReport {
    static func make(from snapshot: DiagnosticReportSnapshot, now: Date = Date()) -> String {
        var lines = [
            "MacScope diagnostics",
            "Version: \(snapshot.appVersion) (\(snapshot.appBuild))",
            "Generated: \(ISO8601DateFormatter().string(from: now))",
            "Lifecycle: \(snapshot.lifecycle.rawValue)",
            "GPU source: \(snapshot.gpuSource.title)"
        ]
        if let system = snapshot.systemInfo {
            lines += [
                "macOS: \(system.operatingSystemVersion)",
                "Model: \(system.modelName)",
                "Architecture: \(system.architecture)",
                "Logical cores: \(system.logicalCoreCount)",
                "Physical memory: \(ByteFormatter.string(fromByteCount: system.physicalMemoryBytes))"
            ]
        } else {
            lines.append("System information: unavailable")
        }
        lines.append("Collectors:")
        for item in snapshot.collectors {
            lines.append("- \(item.collector.title): \(item.status(at: now).title), samples \(item.sampleCount), failures \(item.failureCount), consecutive \(item.consecutiveFailures), avg \(duration(item.averageDuration)), max \(duration(item.maximumDuration))")
        }
        lines.append("Privacy: process names, users, command arguments, file paths, and network endpoints are excluded.")
        return lines.joined(separator: "\n")
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int(seconds * 1_000))ms" : String(format: "%.2fs", seconds)
    }
}
