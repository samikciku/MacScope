import Testing
@testable import MacScope

struct ThermalMonitorTests {
    @Test func readsAValidPublicThermalState() async {
        let stats = await ThermalMonitor().currentStats()

        #expect(ThermalStats.State.allCases.contains(stats.state))
        #expect((0...3).contains(stats.state.rawValue))
    }

    @Test func stateSeverityOrderingMatchesMacOSThermalProgression() {
        #expect(ThermalStats.State.nominal.rawValue < ThermalStats.State.fair.rawValue)
        #expect(ThermalStats.State.fair.rawValue < ThermalStats.State.serious.rawValue)
        #expect(ThermalStats.State.serious.rawValue < ThermalStats.State.critical.rawValue)
    }
}
