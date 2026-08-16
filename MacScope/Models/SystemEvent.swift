import Foundation

struct SystemEvent: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case resourceAlert
        case thermalTransition
        case memoryPressureTransition

        var title: String {
            switch self {
            case .resourceAlert: "Resource Alert"
            case .thermalTransition: "Thermal State"
            case .memoryPressureTransition: "Memory Pressure"
            }
        }
    }

    enum Severity: Int, Equatable, Sendable {
        case information
        case warning
        case critical
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
}
