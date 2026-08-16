import Foundation

enum MonitorCollector: String, CaseIterable, Identifiable, Sendable {
    case memory, cpu, processes, gpu, system, disk, network, battery, thermal
    var id: Self { self }
    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        default: rawValue.capitalized
        }
    }
}

struct CollectorDiagnostic: Equatable, Identifiable, Sendable {
    enum Status: Equatable, Sendable {
        case collecting
        case healthy
        case failing(count: Int)
        case stale

        var title: String {
            switch self {
            case .collecting: "Collecting"
            case .healthy: "Healthy"
            case .failing(let count): "Failing (\(count))"
            case .stale: "Stale"
            }
        }
    }
    let collector: MonitorCollector
    var id: MonitorCollector { collector }
    private(set) var sampleCount = 0
    private(set) var failureCount = 0
    private(set) var consecutiveFailures = 0
    private(set) var lastDuration: TimeInterval = 0
    private(set) var averageDuration: TimeInterval = 0
    private(set) var maximumDuration: TimeInterval = 0
    private(set) var lastSuccess: Date?
    private(set) var lastFailure: Date?

    mutating func record(duration: TimeInterval, succeeded: Bool, at date: Date) {
        let safeDuration = max(0, duration)
        sampleCount += 1
        averageDuration += (safeDuration - averageDuration) / Double(sampleCount)
        lastDuration = safeDuration
        maximumDuration = max(maximumDuration, safeDuration)
        if succeeded {
            consecutiveFailures = 0
            lastSuccess = date
        } else {
            failureCount += 1
            consecutiveFailures += 1
            lastFailure = date
        }
    }

    func status(at date: Date, staleAfter: TimeInterval = 65) -> Status {
        if consecutiveFailures > 0 { return .failing(count: consecutiveFailures) }
        guard let lastSuccess else { return .collecting }
        return date.timeIntervalSince(lastSuccess) > staleAfter ? .stale : .healthy
    }
}

@MainActor
final class MonitoringDiagnostics: ObservableObject {
    enum LifecycleState: String, Sendable {
        case running = "Running"
        case sleeping = "Paused for sleep"
    }

    @Published private(set) var lifecycleState: LifecycleState = .running
    @Published private(set) var collectors: [MonitorCollector: CollectorDiagnostic] = [:]
    @Published private(set) var lastWakeDate: Date?

    var orderedCollectors: [CollectorDiagnostic] {
        MonitorCollector.allCases.compactMap { collectors[$0] }
    }

    func record(_ collector: MonitorCollector, duration: TimeInterval, succeeded: Bool, at date: Date = Date()) {
        var diagnostic = collectors[collector] ?? CollectorDiagnostic(collector: collector)
        diagnostic.record(duration: duration, succeeded: succeeded, at: date)
        collectors[collector] = diagnostic
    }

    func pausedForSleep() { lifecycleState = .sleeping }

    func resumedAfterWake(at date: Date = Date()) {
        lifecycleState = .running
        lastWakeDate = date
    }
}
