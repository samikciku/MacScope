import Foundation

actor ResourceAlertEvaluator {
    private struct RuleState: Sendable {
        var exceedingSince: Date?
        var lastEventAt: Date?
        var latched = false
    }

    private var states: [ResourceAlertKind: RuleState] = [:]

    func evaluate(
        kind: ResourceAlertKind,
        value: Double,
        at timestamp: Date,
        rule: ResourceAlertRule,
        message: @Sendable (Double, Double) -> String
    ) -> ResourceAlertEvent? {
        guard rule.enabled else {
            states[kind] = RuleState()
            return nil
        }

        var state = states[kind] ?? RuleState()
        if hasCleared(value, rule: rule) {
            state.exceedingSince = nil
            state.latched = false
            states[kind] = state
            return nil
        }
        guard hasExceeded(value, rule: rule) else {
            states[kind] = state
            return nil
        }

        if state.exceedingSince == nil { state.exceedingSince = timestamp }
        guard let start = state.exceedingSince,
              timestamp.timeIntervalSince(start) >= rule.duration,
              !state.latched else {
            states[kind] = state
            return nil
        }
        if let lastEventAt = state.lastEventAt,
           timestamp.timeIntervalSince(lastEventAt) < rule.cooldown {
            states[kind] = state
            return nil
        }

        state.latched = true
        state.lastEventAt = timestamp
        states[kind] = state
        return ResourceAlertEvent(
            kind: kind,
            timestamp: timestamp,
            message: message(value, rule.threshold),
            measuredValue: value,
            threshold: rule.threshold
        )
    }

    private func hasExceeded(_ value: Double, rule: ResourceAlertRule) -> Bool {
        switch rule.direction {
        case .above: value >= rule.threshold
        case .below: value <= rule.threshold
        }
    }

    private func hasCleared(_ value: Double, rule: ResourceAlertRule) -> Bool {
        switch rule.direction {
        case .above: value <= rule.threshold - rule.hysteresis
        case .below: value >= rule.threshold + rule.hysteresis
        }
    }
}
