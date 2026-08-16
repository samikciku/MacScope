import Testing
@testable import MacScope

struct MemoryMonitorIntegrationTests {
    @Test func readsPlausibleCurrentSystemValues() async throws {
        let stats = try await MemoryMonitor().currentStats()

        #expect(stats.totalBytes > 0)
        #expect(stats.usedBytes <= stats.totalBytes)
        #expect(stats.availableBytes <= stats.totalBytes)
        #expect(stats.usedBytes + stats.availableBytes == stats.totalBytes)
        #expect(stats.purgeableBytes <= stats.totalBytes)
        #expect(stats.paging.pageInsBytes >= 0)
        #expect(stats.paging.pageOutsBytes >= 0)
        switch stats.swap {
        case .available(let swap):
            #expect(swap.usedBytes <= swap.totalBytes)
        case .unavailable(let reason), .unsupported(let reason):
            #expect(!reason.isEmpty)
        }
        #expect(MemoryStats.Pressure.allCases.contains(stats.pressure))
    }
}
