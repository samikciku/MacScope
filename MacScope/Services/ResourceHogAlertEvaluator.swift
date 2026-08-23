import Foundation

actor ResourceHogAlertEvaluator {
    private struct State: Sendable {
        var exceedingSince: Date?
        var lastEventAt: Date?
        var latched = false
        var lastObservedAt: Date
    }

    private let maximumStates: Int
    private let maximumEventsPerEvaluation: Int
    private var states: [String: State] = [:]

    init(maximumStates: Int = 500, maximumEventsPerEvaluation: Int = 5) {
        self.maximumStates = maximumStates
        self.maximumEventsPerEvaluation = maximumEventsPerEvaluation
    }

    func evaluate(
        measurements: [ResourceHogMeasurement],
        at timestamp: Date,
        enabled: Bool,
        duration: TimeInterval,
        cooldown: TimeInterval
    ) -> [ResourceAlertEvent] {
        guard enabled else {
            states.removeAll(keepingCapacity: true)
            return []
        }

        let observedKeys = Set(measurements.map(\.key))
        states = states.filter { observedKeys.contains($0.key) }
        var candidates: [(key: String, event: ResourceAlertEvent, multiple: Double)] = []

        for measurement in measurements {
            let hysteresis = measurement.threshold * 0.05
            var state = states[measurement.key] ?? State(lastObservedAt: timestamp)
            state.lastObservedAt = timestamp

            if measurement.value <= measurement.threshold - hysteresis {
                state.exceedingSince = nil
                state.latched = false
            } else if measurement.value >= measurement.threshold {
                if state.exceedingSince == nil { state.exceedingSince = timestamp }
                if let started = state.exceedingSince,
                   timestamp.timeIntervalSince(started) >= duration,
                   !state.latched,
                   state.lastEventAt.map({ timestamp.timeIntervalSince($0) >= cooldown }) ?? true {
                    let finding = measurement.finding
                    candidates.append((
                        key: measurement.key,
                        event: ResourceAlertEvent(
                            kind: .resourceHog,
                            timestamp: timestamp,
                            message: "\(finding.applicationName) sustained \(finding.category.title.lowercased()) usage at \(Self.formattedValue(finding)), above its configured threshold.",
                            measuredValue: finding.value,
                            threshold: finding.threshold
                        ),
                        multiple: finding.thresholdMultiple
                    ))
                }
            }
            states[measurement.key] = state
        }

        trimStatesIfNeeded()
        let selected = candidates.sorted { $0.multiple > $1.multiple }.prefix(maximumEventsPerEvaluation)
        for candidate in selected {
            guard var state = states[candidate.key] else { continue }
            state.latched = true
            state.lastEventAt = timestamp
            states[candidate.key] = state
        }
        return selected.map(\.event)
    }

    func stateCountForTesting() -> Int { states.count }

    private func trimStatesIfNeeded() {
        guard states.count > maximumStates else { return }
        let keep = states.sorted { $0.value.lastObservedAt > $1.value.lastObservedAt }.prefix(maximumStates)
        states = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    private static func formattedValue(_ finding: ResourceHogFinding) -> String {
        switch finding.category {
        case .memory: ByteFormatter.string(fromByteCount: UInt64(finding.value))
        case .cpu: (finding.value / 100).formatted(.percent.precision(.fractionLength(1)))
        case .disk, .network: ByteFormatter.string(fromByteCount: UInt64(finding.value)) + "/s"
        case .power: finding.value.formatted(.number.precision(.fractionLength(2))) + " W"
        }
    }
}
