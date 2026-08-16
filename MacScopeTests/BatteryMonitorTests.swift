import Foundation
import Testing
@testable import MacScope

struct BatteryMonitorTests {
    @Test func derivesCapacityHealthWhenDesignCapacityExists() {
        let stats = BatteryStats(
            timestamp: Date(),
            name: "Battery",
            chargeFraction: 0.75,
            isCharging: false,
            powerSource: .battery,
            timeRemainingMinutes: 120,
            timeToFullMinutes: nil,
            health: "Good",
            maximumCapacity: 8_000,
            designCapacity: 10_000,
            adapterWatts: nil
        )

        #expect(stats.healthFraction == 0.8)
    }

    @Test func reportsBatteryOrExplicitUnavailableState() async {
        switch await BatteryMonitor().currentStats() {
        case .available(let stats):
            #expect((0...1).contains(stats.chargeFraction))
            #expect(!stats.name.isEmpty)
        case .unavailable(let reason), .unsupported(let reason):
            #expect(!reason.isEmpty)
        }
    }
}
