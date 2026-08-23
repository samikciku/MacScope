import Foundation

struct SystemEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Equatable, Sendable {
        case resourceAlert
        case thermalTransition
        case memoryPressureTransition
        case batteryPowerTransition
        case lowPowerModeTransition

        var id: Self { self }

        var title: String {
            switch self {
            case .resourceAlert: "Resource Alert"
            case .thermalTransition: "Thermal State"
            case .memoryPressureTransition: "Memory Pressure"
            case .batteryPowerTransition: "Battery Power"
            case .lowPowerModeTransition: "Low Power Mode"
            }
        }
    }

    enum Severity: Int, Equatable, Comparable, Sendable {
        case information
        case warning
        case critical

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: String {
            switch self {
            case .information: "Information"
            case .warning: "Warning"
            case .critical: "Critical"
            }
        }
    }

    let id: UUID
    let timestamp: Date
    let kind: Kind
    let severity: Severity
    let title: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: Kind,
        severity: Severity,
        title: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.severity = severity
        self.title = title
        self.message = message
    }

    var accessibilitySummary: String {
        "\(severity.title), \(kind.title), \(title). \(message)"
    }
}

enum SystemEventSeverityFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case warningAndCritical
    case critical

    var id: Self { self }
    var title: String {
        switch self {
        case .all: "All severities"
        case .warningAndCritical: "Warning or critical"
        case .critical: "Critical only"
        }
    }

    func includes(_ severity: SystemEvent.Severity) -> Bool {
        switch self {
        case .all: true
        case .warningAndCritical: severity >= .warning
        case .critical: severity == .critical
        }
    }
}
