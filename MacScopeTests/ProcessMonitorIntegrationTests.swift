import Darwin
import Testing
@testable import MacScope

struct ProcessMonitorIntegrationTests {
    @Test func enumeratesCurrentProcessWithPlausibleValues() async throws {
        let monitor = ProcessMonitor()
        let snapshots = try await monitor.currentProcesses()
        let current = try #require(snapshots.first { $0.pid == getpid() })

        #expect(!current.name.isEmpty)
        #expect(current.residentBytes > 0)
        #expect(current.threadCount > 0)
        #expect(current.cpuPercent >= 0)
        #expect(current.identity.startTime != nil)
        #expect(current.architecture != nil)
        #expect(current.energyNanojoules != nil)

        try await Task.sleep(for: .milliseconds(100))
        let next = try await monitor.currentProcesses()
        let refreshedCurrent = try #require(next.first { $0.pid == getpid() })
        #expect(refreshedCurrent.wakeupsPerSecond != nil)
        #expect(refreshedCurrent.diskReadBytesPerSecond != nil)
        #expect(refreshedCurrent.diskWriteBytesPerSecond != nil)
        #expect(refreshedCurrent.estimatedPowerWatts != nil)
    }
}
