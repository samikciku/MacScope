import Foundation
import Testing
@testable import MacScope

struct MemoryReclaimReportTests {
    @Test func measuresAvailableFreeAndPurgeableChangesIndependently() {
        let report = MemoryReclaimReport(
            targetName: "Test",
            estimatedResidentBytes: 500,
            before: stats(available: 1_000, free: 400, purgeable: 100),
            after: stats(available: 1_300, free: 350, purgeable: 250)
        )
        #expect(report.availableChange == 300)
        #expect(report.freeChange == -50)
        #expect(report.purgeableChange == 150)
        #expect(report.explanation.contains("Available memory increased"))
    }

    @Test func explainsWhenNoImmediateGainIsVisible() {
        let report = MemoryReclaimReport(
            targetName: "Test",
            estimatedResidentBytes: 500,
            before: stats(available: 1_000, free: 400, purgeable: 100),
            after: stats(available: 900, free: 300, purgeable: 90)
        )
        #expect(report.availableChange == -100)
        #expect(report.explanation.contains("No immediate increase"))
    }

    private func stats(available: UInt64, free: UInt64, purgeable: UInt64) -> MemoryStats {
        MemoryStats(
            timestamp: Date(), totalBytes: 2_000, usedBytes: 2_000 - available,
            availableBytes: available, freeBytes: free, wiredBytes: 0, compressedBytes: 0,
            activeBytes: 0, inactiveBytes: 0, purgeableBytes: purgeable,
            paging: .init(pageInsBytes: 0, pageOutsBytes: 0, pageInsBytesPerSecond: nil, pageOutsBytesPerSecond: nil),
            swap: .unavailable(reason: "test"), pressure: .normal
        )
    }
}
