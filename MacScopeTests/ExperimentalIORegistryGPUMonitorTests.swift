import Testing
@testable import MacScope

struct ExperimentalIORegistryGPUMonitorTests {
    @Test func parsesNamedAGXMetricsWithoutMatchingSimilarKeys() {
        let text = #""Other Device Utilization %"=99,"Device Utilization %"=42,"gpu-core-count"=10"#

        #expect(ExperimentalIORegistryGPUMonitor.number(named: "Device Utilization %", in: text)?.doubleValue == 42)
        #expect(ExperimentalIORegistryGPUMonitor.number(named: "gpu-core-count", in: text)?.intValue == 10)
        #expect(ExperimentalIORegistryGPUMonitor.number(named: "Missing", in: text) == nil)
    }

    @Test func reportsLiveMetricsOrAnExplicitUnsupportedLayout() async {
        do {
            let stats = try await ExperimentalIORegistryGPUMonitor().currentStats()
            if case .available(let utilization) = stats.utilization {
                #expect((0...1).contains(utilization))
            }
        } catch {
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}
