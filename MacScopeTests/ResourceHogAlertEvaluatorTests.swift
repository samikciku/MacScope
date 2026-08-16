import Foundation
import Testing
@testable import MacScope

struct ResourceHogAlertEvaluatorTests {
    @Test func requiresSustainedUsageAndLatchesUntilHysteresisClears() async {
        let evaluator = ResourceHogAlertEvaluator()
        let start = Date(timeIntervalSince1970: 1_000)

        let initial = await evaluate(evaluator, value: 120, at: start)
        let early = await evaluate(evaluator, value: 130, at: start.addingTimeInterval(59))
        let event = await evaluate(evaluator, value: 140, at: start.addingTimeInterval(60))
        let duplicate = await evaluate(evaluator, value: 160, at: start.addingTimeInterval(120))
        _ = await evaluate(evaluator, value: 94, at: start.addingTimeInterval(130))
        let restarted = await evaluate(evaluator, value: 120, at: start.addingTimeInterval(140))

        #expect(initial.isEmpty)
        #expect(early.isEmpty)
        #expect(event.count == 1)
        #expect(event.first?.kind == .resourceHog)
        #expect(duplicate.isEmpty)
        #expect(restarted.isEmpty)
    }

    @Test func disablingClearsStateAndStateCountIsBounded() async {
        let evaluator = ResourceHogAlertEvaluator(maximumStates: 3)
        let date = Date(timeIntervalSince1970: 2_000)
        let measurements = (0..<10).map { measurement(groupID: "group:\($0)", value: 120) }

        _ = await evaluator.evaluate(measurements: measurements, at: date, enabled: true, duration: 60, cooldown: 300)
        #expect(await evaluator.stateCountForTesting() == 3)
        _ = await evaluator.evaluate(measurements: measurements, at: date, enabled: false, duration: 60, cooldown: 300)
        #expect(await evaluator.stateCountForTesting() == 0)
    }

    @Test func capsSimultaneousEventsByHighestThresholdMultiple() async {
        let evaluator = ResourceHogAlertEvaluator(maximumEventsPerEvaluation: 2)
        let start = Date(timeIntervalSince1970: 3_000)
        let measurements = [
            measurement(groupID: "one", value: 110),
            measurement(groupID: "two", value: 300),
            measurement(groupID: "three", value: 200)
        ]
        _ = await evaluator.evaluate(measurements: measurements, at: start, enabled: true, duration: 10, cooldown: 300)
        let events = await evaluator.evaluate(
            measurements: measurements, at: start.addingTimeInterval(10),
            enabled: true, duration: 10, cooldown: 300
        )

        #expect(events.count == 2)
        #expect(events[0].measuredValue == 300)
        #expect(events[1].measuredValue == 200)
    }

    private func evaluate(
        _ evaluator: ResourceHogAlertEvaluator,
        value: Double,
        at date: Date
    ) async -> [ResourceAlertEvent] {
        await evaluator.evaluate(
            measurements: [measurement(groupID: "app:test", value: value)],
            at: date,
            enabled: true,
            duration: 60,
            cooldown: 300
        )
    }

    private func measurement(groupID: String, value: Double) -> ResourceHogMeasurement {
        ResourceHogMeasurement(
            groupID: groupID,
            applicationName: groupID,
            category: .cpu,
            value: value,
            threshold: 100,
            processCount: 1,
            ownerSummary: "sam",
            primaryProcessIdentity: .init(pid: 1, startTime: nil)
        )
    }
}
