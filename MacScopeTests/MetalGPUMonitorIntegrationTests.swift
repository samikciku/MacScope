import Testing
@testable import MacScope

struct MetalGPUMonitorIntegrationTests {
    @Test func reportsDeviceMetadataWithoutFabricatingUtilization() async throws {
        let stats = try await MetalGPUMonitor().currentStats()

        guard case .unsupported(let reason) = stats.utilization else {
            Issue.record("Expected system GPU utilization to be explicitly unsupported")
            return
        }
        #expect(!reason.isEmpty)
        #expect(stats.devices.allSatisfy { !$0.name.isEmpty })
        #expect(stats.sourceDescription != nil)
    }
}
