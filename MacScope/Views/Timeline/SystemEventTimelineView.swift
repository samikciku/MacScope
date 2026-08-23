import SwiftUI

struct SystemEventTimelineView: View {
    @ObservedObject var alertCenter: AlertCenter
    @State private var selectedKind: SystemEvent.Kind?
    @State private var severityFilter: SystemEventSeverityFilter = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            Group {
                if alertCenter.systemEvents.isEmpty {
                    ContentUnavailableView(
                        "No System Events",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Resource alerts, thermal changes, and memory-pressure transitions will appear here.")
                    )
                } else if visibleEvents.isEmpty {
                    ContentUnavailableView(
                        "No Matching Events",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("No timeline events match the selected filters and search.")
                    )
                } else {
                    List(visibleEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .navigationTitle("Event Timeline")
        .searchable(text: $searchText, prompt: "Event title, message, or type")
        .toolbar {
            Button("Clear Timeline") { alertCenter.clearSystemEvents() }
                .disabled(alertCenter.systemEvents.isEmpty)
        }
    }

    private var visibleEvents: [SystemEvent] {
        SystemEventQuery.apply(
            to: alertCenter.systemEvents,
            kind: selectedKind,
            severity: severityFilter,
            searchText: searchText
        )
    }

    private var controls: some View {
        HStack {
            Picker("Event type", selection: $selectedKind) {
                Text("All event types").tag(SystemEvent.Kind?.none)
                ForEach(SystemEvent.Kind.allCases) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
            }
            .frame(width: 190)
            Picker("Severity", selection: $severityFilter) {
                ForEach(SystemEventSeverityFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .frame(width: 190)
            Spacer()
            Text("\(visibleEvents.count) of \(alertCenter.systemEvents.count) events")
                .foregroundStyle(.secondary).monospacedDigit()
                .accessibilityLabel("Showing \(visibleEvents.count) of \(alertCenter.systemEvents.count) timeline events")
        }
        .padding(12)
    }

    private func eventRow(_ event: SystemEvent) -> some View {
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
                HStack(spacing: 8) {
                    Text(event.severity.title)
                    Text(event.kind.title)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.accessibilitySummary)
        .accessibilityValue(event.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
    }

    private func symbol(_ event: SystemEvent) -> String {
        switch event.kind {
        case .resourceAlert: "bell.badge"
        case .thermalTransition: "thermometer.medium"
        case .memoryPressureTransition: "memorychip"
        case .batteryPowerTransition: "powerplug"
        case .lowPowerModeTransition: "leaf"
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
