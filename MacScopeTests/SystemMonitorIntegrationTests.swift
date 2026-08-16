import Testing
@testable import MacScope

struct SystemMonitorIntegrationTests {
    @Test func readsPlausibleCurrentSystemMetadata() async throws {
        let info = try await SystemMonitor().currentInfo()

        #expect(!info.modelName.isEmpty)
        #expect(!info.processorName.isEmpty)
        #expect(!info.operatingSystemVersion.isEmpty)
        #expect(!info.architecture.isEmpty)
        #expect(info.physicalMemoryBytes > 0)
        #expect(info.logicalCoreCount > 0)
        #expect(info.uptimeSeconds > 0)
    }
}
