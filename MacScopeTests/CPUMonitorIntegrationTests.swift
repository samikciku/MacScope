import Testing
@testable import MacScope

struct CPUMonitorIntegrationTests {
    @Test func readsPlausibleCurrentProcessorValues() async throws {
        let stats = try await CPUMonitor().currentStats()

        #expect((0...1).contains(stats.totalUsage))
        #expect((0...1).contains(stats.userUsage))
        #expect((0...1).contains(stats.systemUsage))
        #expect((0...1).contains(stats.idleUsage))
        #expect(!stats.perCoreUsage.isEmpty)
        #expect(stats.perCoreUsage.allSatisfy { (0...1).contains($0) })
        #expect(abs(stats.totalUsage + stats.idleUsage - 1) < 0.000_001)
    }
}
