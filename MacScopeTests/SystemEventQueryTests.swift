import Foundation
import Testing
@testable import MacScope

struct SystemEventQueryTests {
    @Test func filtersByKindSeverityAndSearchInNewestFirstOrder() {
        let events = [
            event(at: 1, kind: .thermalTransition, severity: .information, title: "Thermal normal", message: "Recovered"),
            event(at: 2, kind: .resourceAlert, severity: .warning, title: "High CPU", message: "Firefox exceeded CPU"),
            event(at: 3, kind: .memoryPressureTransition, severity: .critical, title: "Memory pressure", message: "Critical pressure")
        ]

        #expect(SystemEventQuery.apply(to: events, kind: nil, severity: .all, searchText: "").map(\.timestamp.timeIntervalSince1970) == [3, 2, 1])
        #expect(SystemEventQuery.apply(to: events, kind: .resourceAlert, severity: .all, searchText: "").map(\.title) == ["High CPU"])
        #expect(SystemEventQuery.apply(to: events, kind: nil, severity: .warningAndCritical, searchText: "").map(\.title) == ["Memory pressure", "High CPU"])
        #expect(SystemEventQuery.apply(to: events, kind: nil, severity: .critical, searchText: "").map(\.title) == ["Memory pressure"])
        #expect(SystemEventQuery.apply(to: events, kind: nil, severity: .all, searchText: "fireFOX").map(\.title) == ["High CPU"])
        #expect(SystemEventQuery.apply(to: events, kind: nil, severity: .all, searchText: "thermal state").map(\.title) == ["Thermal normal"])
    }

    @Test func accessibilitySummariesDoNotDependOnColorOrIcons() {
        let event = event(
            at: 1, kind: .memoryPressureTransition, severity: .critical,
            title: "Memory pressure", message: "Critical pressure"
        )

        #expect(event.accessibilitySummary == "Critical, Memory Pressure, Memory pressure. Critical pressure")
        #expect(SystemEvent.Severity.information.title == "Information")
        #expect(SystemEvent.Severity.warning.title == "Warning")
        #expect(SystemEvent.Severity.critical.title == "Critical")
    }

    private func event(
        at timestamp: TimeInterval,
        kind: SystemEvent.Kind,
        severity: SystemEvent.Severity,
        title: String,
        message: String
    ) -> SystemEvent {
        SystemEvent(timestamp: Date(timeIntervalSince1970: timestamp), kind: kind, severity: severity, title: title, message: message)
    }
}
