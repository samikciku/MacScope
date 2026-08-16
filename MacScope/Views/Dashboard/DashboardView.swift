import SwiftUI

struct DashboardView: View {
    @ObservedObject var memoryViewModel: MemoryViewModel
    @ObservedObject var cpuViewModel: CPUViewModel
    @ObservedObject var processesViewModel: ProcessesViewModel
    @ObservedObject var gpuViewModel: GPUViewModel
    @ObservedObject var diskViewModel: DiskViewModel
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var batteryViewModel: BatteryViewModel
    @ObservedObject var thermalViewModel: ThermalViewModel
    @ObservedObject var alertCenter: AlertCenter
    let onNavigate: (AppSection) -> Void
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MacScope explains what is slowing down your Mac and helps you act safely.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HealthSummaryCard(assessment: healthAssessment) {
                    onNavigate(healthAssessment.destination)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                MetricCard(title: "Memory", value: memorySummary, systemImage: "memorychip") { onNavigate(.memory) }
                MetricCard(title: "CPU", value: cpuSummary, systemImage: "cpu") { onNavigate(.cpu) }
                MetricCard(title: "GPU", value: gpuSummary, systemImage: "display") { onNavigate(.gpu) }
                MetricCard(title: "Processes", value: processSummary, systemImage: "list.bullet.rectangle") { onNavigate(.processes) }
                MetricCard(title: "Disk", value: diskSummary, systemImage: "internaldrive") { onNavigate(.disk) }
                MetricCard(title: "Network", value: networkSummary, systemImage: "network") { onNavigate(.network) }
                MetricCard(title: "Battery", value: batterySummary, systemImage: "battery.75percent") { onNavigate(.battery) }
                MetricCard(title: "Thermal", value: thermalSummary, systemImage: "thermometer.medium") { onNavigate(.thermal) }
                ProcessRankingCard(
                    title: "Top memory consumers",
                    processes: topMemoryProcesses,
                    value: { ByteFormatter.string(fromByteCount: $0.residentBytes) },
                    onSelect: openProcess
                )
                RecentEventsCard(events: Array(alertCenter.systemEvents.suffix(5).reversed())) { onNavigate(.timeline) }
                dashboardLink(.memory) { CompactMemoryChart(history: memoryViewModel.history) }
                dashboardLink(.cpu) { CompactCPUChart(history: cpuViewModel.history) }
                ProcessRankingCard(
                    title: "Top CPU consumers",
                    processes: topCPUProcesses,
                    value: { ($0.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))) },
                    onSelect: openProcess
                )
                }
            }
            .padding()
        }
        .navigationTitle("Overview")
    }

    private func openProcess(_ process: ProcessSnapshot) {
        processesViewModel.selection = process.identity
        onNavigate(.processes)
    }

    private func dashboardLink<Content: View>(_ section: AppSection, @ViewBuilder content: () -> Content) -> some View {
        Button { onNavigate(section) } label: { content() }
            .buttonStyle(.plain)
            .accessibilityHint("Open \(section.title) details")
    }

    private var memorySummary: String {
        switch memoryViewModel.state {
        case .loading:
            "Loading…"
        case .loaded(let stats):
            "\(ByteFormatter.string(fromByteCount: stats.usedBytes)) of \(ByteFormatter.string(fromByteCount: stats.totalBytes))"
        case .failed:
            "Unavailable"
        }
    }

    private var cpuSummary: String {
        switch cpuViewModel.state {
        case .loading:
            "Loading…"
        case .loaded(let stats):
            stats.totalUsage.formatted(.percent.precision(.fractionLength(1)))
        case .failed:
            "Unavailable"
        }
    }

    private var processSummary: String {
        guard case .loaded(let snapshots) = processesViewModel.state else { return "Loading…" }
        return "\(snapshots.count) running"
    }

    private var gpuSummary: String {
        switch gpuViewModel.state {
        case .loading:
            "Loading…"
        case .failed:
            "Unavailable"
        case .loaded(let stats):
            switch stats.utilization {
            case .available(let utilization):
                utilization.formatted(.percent.precision(.fractionLength(1)))
            case .unavailable:
                "Unavailable"
            case .unsupported:
                "Unsupported"
            }
        }
    }

    private var diskSummary: String {
        switch diskViewModel.state {
        case .loading: "Loading…"
        case .failed: "Unavailable"
        case .loaded(let stats):
            "\(stats.usedFraction.formatted(.percent.precision(.fractionLength(0)))) used · \(ByteFormatter.string(fromByteCount: stats.availableBytes)) free"
        }
    }

    private var networkSummary: String {
        guard case .loaded(let stats) = networkViewModel.state else { return "Loading…" }
        return "↓ \(rate(stats.downloadBytesPerSecond))  ↑ \(rate(stats.uploadBytesPerSecond))"
    }

    private var batterySummary: String {
        switch batteryViewModel.state {
        case .loading: "Loading…"
        case .unavailable: "Unavailable"
        case .unsupported: "No internal battery"
        case .loaded(let stats):
            "\(stats.chargeFraction.formatted(.percent.precision(.fractionLength(0)))) · \(stats.powerSource.rawValue)"
        }
    }

    private var thermalSummary: String {
        guard let stats = thermalViewModel.stats else { return "Loading…" }
        return stats.lowPowerModeEnabled ? "\(stats.state.title) · Low Power Mode" : stats.state.title
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "Collecting…" }
        return ByteFormatter.string(fromByteCount: UInt64(value)) + "/s"
    }

    private var topMemoryProcesses: [ProcessSnapshot] {
        guard case .loaded(let snapshots) = processesViewModel.state else { return [] }
        return Array(snapshots.sorted { $0.residentBytes > $1.residentBytes }.prefix(5))
    }

    private var topCPUProcesses: [ProcessSnapshot] {
        guard case .loaded(let snapshots) = processesViewModel.state else { return [] }
        return Array(snapshots.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5))
    }

    private var healthAssessment: SystemHealthAssessment {
        let pressure: MemoryStats.Pressure? = {
            guard case .loaded(let stats) = memoryViewModel.state else { return nil }
            return stats.pressure
        }()
        let memoryTimestamp: Date? = {
            guard case .loaded(let stats) = memoryViewModel.state else { return nil }
            return stats.timestamp
        }()
        let diskStats: DiskStats? = { guard case .loaded(let stats) = diskViewModel.state else { return nil }; return stats }()
        return SystemHealthAnalyzer.assess(
            memoryPressure: pressure,
            memoryTimestamp: memoryTimestamp,
            cpuHistory: cpuViewModel.history,
            diskUsedFraction: diskStats?.usedFraction,
            diskTimestamp: diskStats?.timestamp,
            thermalState: thermalViewModel.stats?.state,
            thermalTimestamp: thermalViewModel.stats?.timestamp,
            topMemoryProcess: topMemoryProcesses.first,
            topCPUProcess: topCPUProcesses.first
        )
    }
}

private struct HealthSummaryCard: View {
    let assessment: SystemHealthAssessment
    let action: () -> Void

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2).foregroundStyle(color).frame(width: 30)
                VStack(alignment: .leading, spacing: 6) {
                    Text(assessment.title).font(.title3).fontWeight(.semibold)
                    Text(assessment.evidence)
                    Text(assessment.recommendation).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Review") { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(assessment.level == .critical ? .red : nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        } label: {
            Text("Current condition")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current condition: \(assessment.title). \(assessment.evidence) \(assessment.recommendation)")
        .accessibilityHint("Open recommended details")
    }

    private var icon: String {
        switch assessment.level {
        case .collecting: "ellipsis.circle"
        case .partial: "circle.lefthalf.filled"
        case .stale: "clock.badge.exclamationmark"
        case .healthy: "checkmark.circle.fill"
        case .elevated: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }

    private var color: Color {
        switch assessment.level {
        case .collecting, .partial, .stale: .secondary
        case .healthy: .green
        case .elevated: .orange
        case .critical: .red
        }
    }
}

private struct RecentEventsCard: View {
    let events: [SystemEvent]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GroupBox("Recent events") {
            if events.isEmpty {
                Text("No resource or system events")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events) { event in
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: event.kind == .resourceAlert ? "bell.badge" : "waveform.path.ecg")
                                .foregroundStyle(event.severity == .critical ? .red : .secondary)
                            Text(event.title).lineLimit(1)
                            Spacer()
                            Text(event.timestamp, format: .dateTime.hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(.top, 6)
            }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open Timeline details")
        .accessibilityElement(children: .contain)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open \(title) details")
    }
}

private struct ProcessRankingCard: View {
    let title: String
    let processes: [ProcessSnapshot]
    let value: (ProcessSnapshot) -> String
    let onSelect: (ProcessSnapshot) -> Void

    var body: some View {
        GroupBox(title) {
            if processes.isEmpty {
                Text("Collecting process data…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            } else {
                VStack(spacing: 7) {
                    ForEach(processes) { process in
                        Button { onSelect(process) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(process.name).lineLimit(1)
                                    Text(process.owner ?? "Unknown")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(value(process)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open process details")
                    }
                }
                .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
