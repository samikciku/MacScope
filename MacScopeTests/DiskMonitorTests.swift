import Foundation
import Testing
@testable import MacScope

struct DiskMonitorTests {
    @Test func derivesUsedCapacityAndFractionSafely() {
        let stats = DiskStats(
            timestamp: Date(),
            volumeName: "Test",
            mountPath: "/",
            totalBytes: 1_000,
            availableBytes: 250,
            isReadOnly: false,
            ioActivity: .unsupported(reason: "test")
        )
        let overReported = DiskStats(
            timestamp: Date(),
            volumeName: "Test",
            mountPath: "/",
            totalBytes: 100,
            availableBytes: 120,
            isReadOnly: false,
            ioActivity: .unsupported(reason: "test")
        )

        #expect(stats.usedBytes == 750)
        #expect(stats.usedFraction == 0.75)
        #expect(overReported.usedBytes == 0)
        #expect(overReported.usedFraction == 0)
    }

    @Test func derivesIORatesAndRejectsInvalidBaselines() {
        let previous = DiskIOCounterSnapshot(timestamp: 10, readBytes: 1_000, writtenBytes: 500, deviceCount: 2)
        let current = DiskIOCounterSnapshot(timestamp: 12, readBytes: 2_000, writtenBytes: 900, deviceCount: 2)
        let activity = DiskIOCalculations.activity(current: current, previous: previous)
        let regressed = DiskIOCalculations.activity(current: previous, previous: current)

        #expect(activity.readBytesPerSecond == 500)
        #expect(activity.writeBytesPerSecond == 200)
        #expect(activity.totalReadBytes == 2_000)
        #expect(regressed.readBytesPerSecond == nil)
        #expect(regressed.writeBytesPerSecond == nil)
    }

    @Test func readsPlausibleStartupVolumeCapacity() async throws {
        let stats = try await DiskMonitor().currentStats()

        #expect(stats.totalBytes > 0)
        #expect(stats.availableBytes <= stats.totalBytes)
        #expect(stats.usedBytes <= stats.totalBytes)
        #expect(!stats.mountPath.isEmpty)
        switch stats.ioActivity {
        case .available(let activity):
            #expect(activity.deviceCount > 0)
        case .unavailable(let reason), .unsupported(let reason):
            #expect(!reason.isEmpty)
        }
    }
}
