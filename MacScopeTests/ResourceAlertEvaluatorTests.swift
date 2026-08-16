import Foundation
import Testing
@testable import MacScope

struct ResourceAlertEvaluatorTests {
    private let rule = ResourceAlertRule(
        enabled: true,
        threshold: 0.9,
        duration: 120,
        cooldown: 900,
        hysteresis: 0.05
    )

    @Test func requiresSustainedThresholdAndEmitsOncePerExcursion() async {
        let evaluator = ResourceAlertEvaluator()
        let start = Date(timeIntervalSince1970: 1_000)

        let initial = await evaluate(evaluator, value: 0.95, at: start)
        let early = await evaluate(evaluator, value: 0.95, at: start.addingTimeInterval(119))
        let event = await evaluate(evaluator, value: 0.95, at: start.addingTimeInterval(120))
        let duplicate = await evaluate(evaluator, value: 0.99, at: start.addingTimeInterval(500))

        #expect(initial == nil)
        #expect(early == nil)
        #expect(event?.kind == .cpu)
        #expect(event?.measuredValue == 0.95)
        #expect(duplicate == nil)
    }

    @Test func hysteresisResetsButCooldownStillApplies() async {
        let evaluator = ResourceAlertEvaluator()
        let start = Date(timeIntervalSince1970: 2_000)
        _ = await evaluate(evaluator, value: 0.95, at: start)
        _ = await evaluate(evaluator, value: 0.95, at: start.addingTimeInterval(120))
        _ = await evaluate(evaluator, value: 0.84, at: start.addingTimeInterval(130))
        _ = await evaluate(evaluator, value: 0.96, at: start.addingTimeInterval(140))

        let duringCooldown = await evaluate(evaluator, value: 0.96, at: start.addingTimeInterval(300))
        let afterCooldown = await evaluate(evaluator, value: 0.96, at: start.addingTimeInterval(1_021))

        #expect(duringCooldown == nil)
        #expect(afterCooldown != nil)
    }

    @Test func disablingRuleClearsAnInProgressExcursion() async {
        let evaluator = ResourceAlertEvaluator()
        let start = Date(timeIntervalSince1970: 3_000)
        _ = await evaluate(evaluator, value: 0.95, at: start)
        let disabled = ResourceAlertRule(
            enabled: false,
            threshold: rule.threshold,
            duration: rule.duration,
            cooldown: rule.cooldown,
            hysteresis: rule.hysteresis
        )
        _ = await evaluator.evaluate(kind: .cpu, value: 0.95, at: start.addingTimeInterval(100), rule: disabled) { _, _ in "event" }
        let result = await evaluate(evaluator, value: 0.95, at: start.addingTimeInterval(121))

        #expect(result == nil)
    }

    @Test func belowThresholdRuleUsesInverseHysteresis() async {
        let evaluator = ResourceAlertEvaluator()
        let start = Date(timeIntervalSince1970: 4_000)
        let lowRule = ResourceAlertRule(
            enabled: true,
            threshold: 0.2,
            duration: 60,
            cooldown: 300,
            hysteresis: 0.05,
            direction: .below
        )
        _ = await evaluator.evaluate(kind: .battery, value: 0.19, at: start, rule: lowRule) { _, _ in "low" }
        let event = await evaluator.evaluate(kind: .battery, value: 0.18, at: start.addingTimeInterval(60), rule: lowRule) { _, _ in "low" }
        let duplicate = await evaluator.evaluate(kind: .battery, value: 0.22, at: start.addingTimeInterval(70), rule: lowRule) { _, _ in "low" }
        _ = await evaluator.evaluate(kind: .battery, value: 0.26, at: start.addingTimeInterval(80), rule: lowRule) { _, _ in "low" }

        #expect(event != nil)
        #expect(duplicate == nil)
        let restarted = await evaluator.evaluate(kind: .battery, value: 0.19, at: start.addingTimeInterval(90), rule: lowRule) { _, _ in "low" }
        #expect(restarted == nil)
    }

    private func evaluate(
        _ evaluator: ResourceAlertEvaluator,
        value: Double,
        at date: Date
    ) async -> ResourceAlertEvent? {
        await evaluator.evaluate(kind: .cpu, value: value, at: date, rule: rule) { _, _ in "event" }
    }
}

struct AlertCenterTests {
    @Test @MainActor func boundsLocalHistoryToTwoHundredEvents() {
        let center = AlertCenter()
        for index in 0..<205 {
            center.record(
                ResourceAlertEvent(
                    kind: .cpu,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                    message: "Event \(index)",
                    measuredValue: 1,
                    threshold: 0.9
                ),
                postNotification: false
            )
        }

        #expect(center.events.count == 200)
        #expect(center.events.first?.message == "Event 5")
        #expect(center.events.last?.message == "Event 204")
        #expect(center.systemEvents.count == 205)
    }

    @Test @MainActor func recordsOnlyActualThermalTransitions() {
        let center = AlertCenter()
        let start = Date(timeIntervalSince1970: 10)
        center.observeThermalState(.init(timestamp: start, state: .nominal, lowPowerModeEnabled: false))
        center.observeThermalState(.init(timestamp: start.addingTimeInterval(1), state: .nominal, lowPowerModeEnabled: false))
        center.observeThermalState(.init(timestamp: start.addingTimeInterval(2), state: .serious, lowPowerModeEnabled: false))
        center.observeThermalState(.init(timestamp: start.addingTimeInterval(3), state: .nominal, lowPowerModeEnabled: false))

        #expect(center.systemEvents.count == 2)
        #expect(center.systemEvents.first?.severity == .critical)
        #expect(center.systemEvents.last?.severity == .information)
    }

    @Test @MainActor func boundsSystemTimelineToFiveHundredEvents() {
        let center = AlertCenter()
        for index in 0..<505 {
            center.record(
                ResourceAlertEvent(
                    kind: .cpu,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                    message: "Timeline \(index)",
                    measuredValue: 1,
                    threshold: 0.9
                ),
                postNotification: false
            )
        }

        #expect(center.systemEvents.count == 500)
        #expect(center.systemEvents.first?.message == "Timeline 5")
        #expect(center.systemEvents.last?.message == "Timeline 504")
    }
}
