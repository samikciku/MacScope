import Testing
@testable import MacScope

struct CPUCalculationsTests {
    @Test func calculatesAggregateAndPerCoreUsageFromDeltas() throws {
        let previous = [
            CPUCoreTicks(user: 100, system: 50, idle: 200, nice: 10),
            CPUCoreTicks(user: 200, system: 100, idle: 300, nice: 20)
        ]
        let current = [
            CPUCoreTicks(user: 130, system: 60, idle: 260, nice: 10),
            CPUCoreTicks(user: 240, system: 120, idle: 340, nice: 20)
        ]

        let result = try #require(CPUCalculations.usage(previous: previous, current: current))

        #expect(abs(result.total - 0.5) < 0.000_001)
        #expect(abs(result.user - 0.35) < 0.000_001)
        #expect(abs(result.system - 0.15) < 0.000_001)
        #expect(abs(result.idle - 0.5) < 0.000_001)
        #expect(abs(result.perCore[0] - 0.4) < 0.000_001)
        #expect(abs(result.perCore[1] - 0.6) < 0.000_001)
    }

    @Test func handlesWrappingTickCounters() throws {
        let previous = [CPUCoreTicks(user: .max - 4, system: 0, idle: 0, nice: 0)]
        let current = [CPUCoreTicks(user: 5, system: 0, idle: 10, nice: 0)]

        let result = try #require(CPUCalculations.usage(previous: previous, current: current))

        #expect(abs(result.total - 0.5) < 0.000_001)
    }

    @Test func rejectsMismatchedCoreCounts() {
        let result = CPUCalculations.usage(
            previous: [CPUCoreTicks(user: 0, system: 0, idle: 0, nice: 0)],
            current: []
        )

        #expect(result == nil)
    }
}
