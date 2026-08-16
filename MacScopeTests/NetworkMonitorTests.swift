import Testing
@testable import MacScope

struct NetworkMonitorTests {
    @Test func parsesPerProcessNettopCountersIncludingDottedNames() {
        let output = """
        ,bytes_in,bytes_out,
        firefox.90157,9543,20733,
        Codex (Service).10444,194408,259357,
        com.example.helper.42,100,200,
        """

        let counters = ProcessNetworkMonitor.parse(output)

        #expect(counters.count == 3)
        #expect(counters[0] == .init(pid: 90157, name: "firefox", receivedBytes: 9543, sentBytes: 20733))
        #expect(counters[1].name == "Codex (Service)")
        #expect(counters[2] == .init(pid: 42, name: "com.example.helper", receivedBytes: 100, sentBytes: 200))
    }

    @Test func derivesRatesFromConsecutiveCounters() {
        let previous = NetworkCounterSnapshot(timestamp: 10, receivedBytes: 1_000, transmittedBytes: 500)
        let current = NetworkCounterSnapshot(timestamp: 12, receivedBytes: 3_000, transmittedBytes: 1_100)
        let rates = NetworkCalculations.rates(current: current, previous: previous)

        #expect(rates.download == 1_000)
        #expect(rates.upload == 300)
    }

    @Test func withholdsRatesForMissingOrRegressedBaselines() {
        let current = NetworkCounterSnapshot(timestamp: 10, receivedBytes: 1_000, transmittedBytes: 500)
        let missing = NetworkCalculations.rates(current: current, previous: nil)
        let regressed = NetworkCalculations.rates(
            current: current,
            previous: .init(timestamp: 9, receivedBytes: 1_001, transmittedBytes: 501)
        )

        #expect(missing.download == nil)
        #expect(missing.upload == nil)
        #expect(regressed.download == nil)
        #expect(regressed.upload == nil)
    }

    @Test func readsCurrentInterfaceCounters() async throws {
        let stats = try await NetworkMonitor().currentStats()

        #expect(stats.interfaces.allSatisfy { !$0.name.isEmpty })
        #expect(stats.downloadBytesPerSecond == nil)
        #expect(stats.uploadBytesPerSecond == nil)
    }
}
