import SwiftUI

struct MemoryView: View {
    @ObservedObject var viewModel: MemoryViewModel
    @ObservedObject var processesViewModel: ProcessesViewModel
    @State private var showsConsumers = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Reading memory statistics…")
            case .failed(let message):
                ContentUnavailableView(
                    "Memory Statistics Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let stats):
                memoryContent(stats)
            }
        }
        .navigationTitle("Memory")
        .sheet(isPresented: $showsConsumers) {
            MemoryConsumersView(
                systemUsedBytes: currentUsedBytes,
                memoryViewModel: viewModel,
                processesViewModel: processesViewModel
            )
            .frame(minWidth: 760, minHeight: 580)
        }
    }

    private func memoryContent(_ stats: MemoryStats) -> some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                metricRow("Total", stats.totalBytes)
                if DistributionChannel.allowsProcessInspection {
                    GridRow {
                    Button {
                        showsConsumers = true
                    } label: {
                        HStack {
                            Text("Used")
                            Spacer()
                            Text(ByteFormatter.string(fromByteCount: stats.usedBytes))
                                .monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .gridCellColumns(2)
                    .accessibilityLabel("Used memory, \(ByteFormatter.string(fromByteCount: stats.usedBytes))")
                    .accessibilityHint("Open processes using memory")
                    }
                } else {
                    metricRow("Used", stats.usedBytes)
                }
                metricRow("Available", stats.availableBytes)
                Divider()
                metricRow("Free", stats.freeBytes)
                metricRow("Active", stats.activeBytes)
                metricRow("Inactive", stats.inactiveBytes)
                metricRow("Purgeable", stats.purgeableBytes)
                metricRow("Wired", stats.wiredBytes)
                metricRow("Compressed", stats.compressedBytes)
                Divider()
                metricRow("Page-ins total", stats.paging.pageInsBytes)
                rateRow("Page-ins rate", stats.paging.pageInsBytesPerSecond)
                metricRow("Page-outs total", stats.paging.pageOutsBytes)
                rateRow("Page-outs rate", stats.paging.pageOutsBytesPerSecond)
                Divider()
                swapRows(stats.swap)
                GridRow {
                    Text("Memory pressure")
                    VStack(alignment: .leading, spacing: 4) {
                        Label(stats.pressure.title, systemImage: pressureIcon(stats.pressure))
                            .foregroundStyle(pressureColor(stats.pressure))
                        Text(stats.pressure.guidance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Memory pressure \(stats.pressure.title). \(stats.pressure.guidance)")
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            MemoryHistoryChart(history: viewModel.history)
                .frame(height: 240)
                .padding(.horizontal, 24)
            MemoryPagingHistoryChart(history: viewModel.history)
                .frame(height: 200)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    private var currentUsedBytes: UInt64 {
        guard case .loaded(let stats) = viewModel.state else { return 0 }
        return stats.usedBytes
    }

    private func pressureColor(_ pressure: MemoryStats.Pressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        case .unavailable: .secondary
        }
    }

    private func pressureIcon(_ pressure: MemoryStats.Pressure) -> String {
        switch pressure {
        case .normal: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unavailable: "clock"
        }
    }

    @ViewBuilder
    private func swapRows(_ swap: MetricAvailability<MemoryStats.Swap>) -> some View {
        switch swap {
        case .available(let values):
            metricRow("Swap used", values.usedBytes)
            metricRow("Swap total", values.totalBytes)
        case .unavailable(let reason), .unsupported(let reason):
            GridRow {
                Text("Swap")
                Text("Unavailable")
                    .foregroundStyle(.secondary)
                    .help(reason)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(reason)
        }
    }

    private func metricRow(_ label: String, _ bytes: UInt64) -> some View {
        GridRow {
            Text(label)
            Text(ByteFormatter.string(fromByteCount: bytes))
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private func rateRow(_ label: String, _ bytesPerSecond: Double?) -> some View {
        GridRow {
            Text(label)
            if let bytesPerSecond, bytesPerSecond >= 0 {
                Text("\(ByteFormatter.string(fromByteCount: UInt64(bytesPerSecond)))/s")
                    .monospacedDigit()
                    .textSelection(.enabled)
            } else {
                Text("Collecting…").foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
