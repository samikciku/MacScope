import SwiftUI

struct ResourceHogsView: View {
    @ObservedObject var processesViewModel: ProcessesViewModel
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var settings: MonitoringSettings
    @ObservedObject var alertCenter: AlertCenter
    @State private var selectedIdentity: ProcessSnapshot.Identity?
    @State private var selectedCategory: ResourceHogCategory?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            thresholdControls
            Divider()
            content
        }
        .navigationTitle("Resource Hogs")
        .searchable(text: $searchText, prompt: "Application or user")
        .sheet(item: selectedProcess) { process in
            ProcessDetailView(identity: process.identity, viewModel: processesViewModel)
                .frame(minWidth: 560, minHeight: 580)
        }
    }

    private var allFindings: [ResourceHogFinding] {
        let traffic: [ProcessNetworkUsage]
        if case .available(let values) = networkViewModel.processTraffic { traffic = values } else { traffic = [] }
        return ResourceHogAnalyzer.findings(
            groups: processesViewModel.applicationGroups,
            processNetworkUsage: traffic,
            thresholds: settings.resourceHogThresholds
        )
    }

    private var findings: [ResourceHogFinding] {
        ResourceHogQuery.filter(allFindings, category: selectedCategory, searchText: searchText)
    }

    private var recentAlerts: [ResourceAlertEvent] {
        alertCenter.events.reversed().filter { $0.kind == .resourceHog }.prefix(20).map { $0 }
    }

    private var selectedProcess: Binding<ProcessSnapshot?> {
        Binding(
            get: { selectedIdentity.flatMap(processesViewModel.process(with:)) },
            set: { selectedIdentity = $0?.identity }
        )
    }

    private var thresholdControls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Category", selection: $selectedCategory) {
                    Text("All categories").tag(ResourceHogCategory?.none)
                    ForEach(ResourceHogCategory.allCases) { category in
                        Text(category.title).tag(Optional(category))
                    }
                }
                .frame(width: 190)
                Spacer()
                Text("\(findings.count) of \(allFindings.count) findings")
                    .foregroundStyle(.secondary).monospacedDigit()
                    .accessibilityLabel("Showing \(findings.count) of \(allFindings.count) resource hog findings")
            }
            DisclosureGroup("Thresholds and alerts") {
                Toggle("Alert on sustained resource hogs", isOn: $settings.hogAlertsEnabled)
                    .padding(.top, 8)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    thresholdRow("Memory", value: $settings.hogMemoryThresholdGB, range: 0.25...128, step: 0.25, suffix: "GB")
                    thresholdRow("CPU", value: $settings.hogCPUThresholdPercent, range: 10...2_000, step: 10, suffix: "%")
                    thresholdRow("Disk", value: $settings.hogDiskThresholdMBps, range: 1...5_000, step: 10, suffix: "MB/s")
                    thresholdRow("Network", value: $settings.hogNetworkThresholdMBps, range: 1...5_000, step: 10, suffix: "MB/s")
                    thresholdRow("Measured power", value: $settings.hogPowerThresholdWatts, range: 0.1...200, step: 1, suffix: "W")
                }
                Text("Alerts use the duration, cooldown, and notification settings from Alerts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        switch processesViewModel.state {
        case .loading:
            ProgressView("Analyzing application usage…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView("Analysis Unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
        case .loaded:
            List {
                Section("Current findings") {
                    if findings.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Resource Hogs" : "No Matching Findings",
                            systemImage: "checkmark.circle",
                            description: Text("No application currently matches the selected category, search, and thresholds.")
                        )
                    } else {
                        ForEach(findings) { finding in
                            Button { selectedIdentity = finding.primaryProcessIdentity } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: finding.category.systemImage).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(finding.applicationName).fontWeight(.medium)
                                        Text("\(finding.category.title) · \(finding.processCount) process\(finding.processCount == 1 ? "" : "es") · user \(finding.ownerSummary)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(formattedValue(finding)).monospacedDigit()
                                        Text(finding.thresholdMultiple.formatted(.number.precision(.fractionLength(1))) + "× threshold")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Open the largest process in this application group")
                            .accessibilityLabel(finding.accessibilitySummary(valueDescription: formattedValue(finding)))
                        }
                    }
                }
                Section("Recent sustained alerts") {
                    if recentAlerts.isEmpty {
                        Text("No Resource Hog alerts have been emitted in this session.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentAlerts) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.message)
                                Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(event.kind.title). \(event.message)")
                            .accessibilityValue(event.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
                        }
                    }
                }
            }
        }
    }

    private func thresholdRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        GridRow {
            Text(label)
            Stepper(value: value, in: range, step: step) {
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(value.wrappedValue < 10 ? 1 : 0))) + " " + suffix)
                    .monospacedDigit().frame(width: 110, alignment: .trailing)
            }
        }
    }

    private func formattedValue(_ finding: ResourceHogFinding) -> String {
        switch finding.category {
        case .memory:
            ByteFormatter.string(fromByteCount: UInt64(finding.value))
        case .cpu:
            (finding.value / 100).formatted(.percent.precision(.fractionLength(1)))
        case .disk, .network:
            ByteFormatter.string(fromByteCount: UInt64(finding.value)) + "/s"
        case .power:
            finding.value.formatted(.number.precision(.fractionLength(2))) + " W"
        }
    }
}
