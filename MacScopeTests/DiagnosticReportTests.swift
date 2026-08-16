import Foundation
import Testing
@testable import MacScope

@MainActor
struct DiagnosticReportTests {
    @Test func reportContainsOperationalEvidenceButNoPrivateProcessData() {
        let diagnostics = MonitoringDiagnostics()
        diagnostics.record(.cpu, duration: 0.125, succeeded: true, at: Date(timeIntervalSince1970: 100))
        let report = DiagnosticReport.make(from: .init(
            appVersion: "2.0",
            appBuild: "42",
            systemInfo: .init(modelName: "Mac", processorName: "Apple Silicon", physicalMemoryBytes: 16_000_000_000, operatingSystemVersion: "macOS 15", architecture: "arm64", uptimeSeconds: 12, logicalCoreCount: 10),
            gpuSource: .metal,
            lifecycle: diagnostics.lifecycleState,
            collectors: diagnostics.orderedCollectors
        ), now: Date(timeIntervalSince1970: 101))

        #expect(report.contains("Version: 2.0 (42)"))
        #expect(report.contains("CPU: Healthy"))
        #expect(report.contains("process names, users, command arguments, file paths, and network endpoints are excluded"))
        #expect(!report.contains(NSUserName()))
        #expect(!report.contains("/Users/"))
    }

    @Test func collectorStatusDistinguishesCollectingFailureAndStale() {
        var item = CollectorDiagnostic(collector: .network)
        #expect(item.status(at: Date()) == .collecting)
        item.record(duration: 0.1, succeeded: false, at: Date(timeIntervalSince1970: 1))
        #expect(item.status(at: Date(timeIntervalSince1970: 2)) == .failing(count: 1))
        item.record(duration: 0.1, succeeded: true, at: Date(timeIntervalSince1970: 3))
        #expect(item.status(at: Date(timeIntervalSince1970: 100), staleAfter: 10) == .stale)
    }
}
