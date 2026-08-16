import SwiftUI

struct AlertsView: View {
    @ObservedObject var alertCenter: AlertCenter
    @ObservedObject var settings: MonitoringSettings

    var body: some View {
        Form {
            Section("CPU") {
                Toggle("Alert on sustained high CPU", isOn: $settings.cpuAlertEnabled)
                LabeledContent("Threshold") {
                    Text(settings.cpuAlertThreshold, format: .percent.precision(.fractionLength(0)))
                }
                Slider(value: $settings.cpuAlertThreshold, in: 0.5...1, step: 0.05)
                    .disabled(!settings.cpuAlertEnabled)
            }

            Section("Swap") {
                Toggle("Alert on sustained high swap", isOn: $settings.swapAlertEnabled)
                Stepper(
                    "Threshold: \(settings.swapAlertThresholdGB, specifier: "%.1f") GB",
                    value: $settings.swapAlertThresholdGB,
                    in: 0.5...128,
                    step: 0.5
                )
                .disabled(!settings.swapAlertEnabled)
            }

            Section("Thermal") {
                Toggle("Alert on sustained serious thermal pressure", isOn: $settings.thermalAlertEnabled)
                Text("Uses macOS system thermal states. The alert clears after returning to fair or nominal.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Disk") {
                Toggle("Alert when startup disk is almost full", isOn: $settings.diskAlertEnabled)
                LabeledContent("Used-space threshold") {
                    Text(settings.diskAlertThreshold, format: .percent.precision(.fractionLength(0)))
                }
                Slider(value: $settings.diskAlertThreshold, in: 0.7...0.98, step: 0.01)
                    .disabled(!settings.diskAlertEnabled)
            }

            Section("Battery") {
                Toggle("Alert on sustained low battery", isOn: $settings.batteryAlertEnabled)
                LabeledContent("Charge threshold") {
                    Text(settings.batteryAlertThreshold, format: .percent.precision(.fractionLength(0)))
                }
                Slider(value: $settings.batteryAlertThreshold, in: 0.05...0.5, step: 0.05)
                    .disabled(!settings.batteryAlertEnabled)
                Text("No alert is generated on Macs without an internal battery.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Timing") {
                Picker("Duration", selection: $settings.alertDuration) {
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                    Text("5 minutes").tag(TimeInterval(300))
                }
                Picker("Cooldown", selection: $settings.alertCooldown) {
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1_800))
                    Text("1 hour").tag(TimeInterval(3_600))
                }
            }

            Section("Notifications") {
                Toggle("Post macOS notifications", isOn: notificationBinding)
                if alertCenter.notificationAuthorizationDenied {
                    Text("Notification permission was not granted. You can change it in System Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if alertCenter.events.isEmpty {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "bell.slash",
                        description: Text("Sustained threshold events will appear here.")
                    )
                } else {
                    ForEach(alertCenter.events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(event.kind.title, systemImage: eventSymbol(event.kind))
                                .font(.headline)
                            Text(event.message)
                            Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                HStack {
                    Text("Recent Events")
                    Spacer()
                    Button("Clear") { alertCenter.clear() }
                        .disabled(alertCenter.events.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Alerts")
    }

    private func eventSymbol(_ kind: ResourceAlertKind) -> String {
        switch kind {
        case .cpu: "cpu"
        case .swap: "memorychip"
        case .thermal: "thermometer.high"
        case .diskCapacity: "internaldrive.fill"
        case .battery: "battery.25percent"
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { settings.notificationsEnabled },
            set: { enabled in
                guard enabled else {
                    settings.notificationsEnabled = false
                    return
                }
                Task {
                    settings.notificationsEnabled = await alertCenter.requestNotificationAuthorization()
                }
            }
        )
    }
}
