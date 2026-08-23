import Foundation
import Testing
@testable import MacScope

@MainActor
struct MonitoringDiagnosticsTests {
    @Test func tracksDurationsAndConsecutiveFailuresWithoutHistoryGrowth() {
        let diagnostics = MonitoringDiagnostics()
        diagnostics.record(.cpu, duration: 0.1, succeeded: true)
        diagnostics.record(.cpu, duration: 0.3, succeeded: false)
        diagnostics.record(.cpu, duration: 0.2, succeeded: false)

        let cpu = diagnostics.collectors[.cpu]
        #expect(cpu?.sampleCount == 3)
        #expect(cpu?.failureCount == 2)
        #expect(cpu?.consecutiveFailures == 2)
        #expect(cpu?.averageDuration == 0.2)
        #expect(cpu?.maximumDuration == 0.3)
    }

    @Test func sleepWakeLifecycleIsExplicit() {
        let diagnostics = MonitoringDiagnostics()
        diagnostics.pausedForSleep()
        #expect(diagnostics.lifecycleState == .sleeping)
        diagnostics.resumedAfterWake(at: Date(timeIntervalSince1970: 10))
        #expect(diagnostics.lifecycleState == .running)
        #expect(diagnostics.lastWakeDate == Date(timeIntervalSince1970: 10))
    }
}
