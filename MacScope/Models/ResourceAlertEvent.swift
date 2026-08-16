import Foundation

enum ResourceAlertKind: String, Equatable, Sendable {
    case cpu
    case swap
    case thermal
    case diskCapacity
    case battery
    case resourceHog

    var title: String {
        switch self {
        case .cpu: "High CPU Usage"
        case .swap: "High Swap Usage"
        case .thermal: "High Thermal Pressure"
        case .diskCapacity: "Disk Almost Full"
        case .battery: "Low Battery"
        case .resourceHog: "Application Resource Hog"
        }
    }
}

struct ResourceAlertEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ResourceAlertKind
    let timestamp: Date
    let message: String
    let measuredValue: Double
    let threshold: Double

    init(
        id: UUID = UUID(),
        kind: ResourceAlertKind,
        timestamp: Date,
        message: String,
        measuredValue: Double,
        threshold: Double
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.message = message
        self.measuredValue = measuredValue
        self.threshold = threshold
    }
}

struct ResourceAlertRule: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case above
        case below
    }

    let enabled: Bool
    let threshold: Double
    let duration: TimeInterval
    let cooldown: TimeInterval
    let hysteresis: Double
    let direction: Direction

    init(
        enabled: Bool,
        threshold: Double,
        duration: TimeInterval,
        cooldown: TimeInterval,
        hysteresis: Double,
        direction: Direction = .above
    ) {
        self.enabled = enabled
        self.threshold = threshold
        self.duration = duration
        self.cooldown = cooldown
        self.hysteresis = hysteresis
        self.direction = direction
    }
}
