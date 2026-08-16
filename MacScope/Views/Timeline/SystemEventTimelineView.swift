import SwiftUI

struct SystemEventTimelineView: View {
    @ObservedObject var alertCenter: AlertCenter

    var body: some View {
        Group {
            if alertCenter.systemEvents.isEmpty {
                ContentUnavailableView(
                    "No System Events",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Resource alerts and thermal-state transitions will appear here.")
                )
            } else {
                List(alertCenter.systemEvents.reversed()) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbol(event))
                            .foregroundStyle(color(event.severity))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.title).font(.headline)
                                Spacer()
                                Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(event.message)
                            Text(event.kind.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Event Timeline")
        .toolbar {
            Button("Clear Timeline") { alertCenter.clearSystemEvents() }
                .disabled(alertCenter.systemEvents.isEmpty)
        }
    }

    private func symbol(_ event: SystemEvent) -> String {
        switch event.kind {
        case .resourceAlert: "bell.badge"
        case .thermalTransition: "thermometer.medium"
        case .memoryPressureTransition: "memorychip"
        }
    }

    private func color(_ severity: SystemEvent.Severity) -> Color {
        switch severity {
        case .information: .secondary
        case .warning: .orange
        case .critical: .red
        }
    }
}
