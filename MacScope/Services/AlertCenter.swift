import Foundation
import UserNotifications

@MainActor
final class AlertCenter: ObservableObject {
    @Published private(set) var events: [ResourceAlertEvent] = []
    @Published private(set) var systemEvents: [SystemEvent] = []
    @Published private(set) var notificationAuthorizationDenied = false
    private var eventBuffer = RingBuffer<ResourceAlertEvent>(capacity: 200)
    private var systemEventBuffer = RingBuffer<SystemEvent>(capacity: 500)
    private var previousThermalState: ThermalStats.State?
    private var previousMemoryPressure: MemoryStats.Pressure?

    func record(_ event: ResourceAlertEvent, postNotification: Bool) {
        eventBuffer.append(event)
        events = Array(eventBuffer)
        appendSystemEvent(.init(
            id: event.id,
            timestamp: event.timestamp,
            kind: .resourceAlert,
            severity: event.kind == .thermal ? .critical : .warning,
            title: event.kind.title,
            message: event.message
        ))
        guard postNotification else { return }

        let content = UNMutableNotificationContent()
        content.title = event.kind.title
        content.body = event.message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func requestNotificationAuthorization() async -> Bool {
        do {
            let allowed = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            notificationAuthorizationDenied = !allowed
            return allowed
        } catch {
            notificationAuthorizationDenied = true
            return false
        }
    }

    func clear() {
        eventBuffer = RingBuffer(capacity: 200)
        events = []
    }

    func observeThermalState(_ stats: ThermalStats) {
        defer { previousThermalState = stats.state }
        guard let previousThermalState, previousThermalState != stats.state else { return }
        appendSystemEvent(.init(
            timestamp: stats.timestamp,
            kind: .thermalTransition,
            severity: severity(for: stats.state),
            title: "Thermal state: \(stats.state.title)",
            message: "System thermal pressure changed from \(previousThermalState.title.lowercased()) to \(stats.state.title.lowercased())."
        ))
    }

    func observeMemoryPressure(_ pressure: MemoryStats.Pressure, at timestamp: Date) {
        guard pressure != .unavailable else { return }
        defer { previousMemoryPressure = pressure }
        guard let previousMemoryPressure, previousMemoryPressure != pressure else { return }
        appendSystemEvent(.init(
            timestamp: timestamp,
            kind: .memoryPressureTransition,
            severity: memorySeverity(pressure),
            title: "Memory pressure: \(pressure.title)",
            message: "System memory pressure changed from \(previousMemoryPressure.title.lowercased()) to \(pressure.title.lowercased())."
        ))
    }

    func clearSystemEvents() {
        systemEventBuffer = RingBuffer(capacity: 500)
        systemEvents = []
    }

    private func appendSystemEvent(_ event: SystemEvent) {
        systemEventBuffer.append(event)
        systemEvents = Array(systemEventBuffer)
    }

    private func severity(for state: ThermalStats.State) -> SystemEvent.Severity {
        switch state {
        case .nominal: .information
        case .fair: .warning
        case .serious, .critical: .critical
        }
    }

    private func memorySeverity(_ pressure: MemoryStats.Pressure) -> SystemEvent.Severity {
        switch pressure {
        case .normal, .unavailable: .information
        case .warning: .warning
        case .critical: .critical
        }
    }
}
