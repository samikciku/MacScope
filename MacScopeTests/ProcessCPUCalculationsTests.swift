import Testing
@testable import MacScope

struct ProcessCPUCalculationsTests {
    @Test func usesOneCoreEqualsOneHundredPercentConvention() throws {
        let percent = try #require(ProcessCPUCalculations.percent(
            previousNanoseconds: 1_000_000_000,
            currentNanoseconds: 3_000_000_000,
            elapsedSeconds: 1
        ))

        #expect(abs(percent - 200) < 0.000_001)
    }

    @Test func rejectsInvalidDeltas() {
        #expect(ProcessCPUCalculations.percent(
            previousNanoseconds: 10,
            currentNanoseconds: 5,
            elapsedSeconds: 1
        ) == nil)
        #expect(ProcessCPUCalculations.percent(
            previousNanoseconds: 0,
            currentNanoseconds: 10,
            elapsedSeconds: 0
        ) == nil)
    }
}

struct ProcessResourceCalculationsTests {
    @Test func derivesWakeupDiskAndPowerRates() {
        let previous = ProcessCumulativeResources(
            wakeups: 100,
            diskReadBytes: 1_000,
            diskWriteBytes: 500,
            energyNanojoules: 1_000_000_000
        )
        let current = ProcessCumulativeResources(
            wakeups: 120,
            diskReadBytes: 3_000,
            diskWriteBytes: 1_500,
            energyNanojoules: 3_000_000_000
        )
        let rates = ProcessResourceCalculations.rates(previous: previous, current: current, elapsedSeconds: 2)

        #expect(rates?.wakeupsPerSecond == 10)
        #expect(rates?.diskReadBytesPerSecond == 1_000)
        #expect(rates?.diskWriteBytesPerSecond == 500)
        #expect(rates?.powerWatts == 1)
    }

    @Test func rejectsCounterRegression() {
        let previous = ProcessCumulativeResources(wakeups: 2, diskReadBytes: 2, diskWriteBytes: 2, energyNanojoules: 2)
        let current = ProcessCumulativeResources(wakeups: 1, diskReadBytes: 2, diskWriteBytes: 2, energyNanojoules: 2)

        #expect(ProcessResourceCalculations.rates(previous: previous, current: current, elapsedSeconds: 1) == nil)
    }
}
