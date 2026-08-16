import Charts
import SwiftUI

struct GPUView: View {
    @ObservedObject var viewModel: GPUViewModel

    var body: some View {
        VStack(spacing: 12) {
            Picker("GPU data source", selection: $viewModel.source) {
                ForEach(GPUDataSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .onChange(of: viewModel.source) { _, _ in
                Task { await viewModel.refresh() }
            }

            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Discovering GPU devices…")
                case .failed(let message):
                    ContentUnavailableView(
                        "GPU Information Unavailable",
                        systemImage: "display.trianglebadge.exclamationmark",
                        description: Text(message)
                    )
                case .loaded(let stats):
                    gpuContent(stats)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("GPU")
    }

    private func gpuContent(_ stats: GPUStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                utilizationStatus(stats.utilization)

                if stats.rendererUtilization != nil || stats.tilerUtilization != nil || stats.inUseMemoryBytes != nil {
                    GroupBox("Live GPU details") {
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            metricRow("Renderer", stats.rendererUtilization?.formatted(.percent.precision(.fractionLength(1))) ?? "Unavailable")
                            metricRow("Tiler", stats.tilerUtilization?.formatted(.percent.precision(.fractionLength(1))) ?? "Unavailable")
                            metricRow("Memory in use", stats.inUseMemoryBytes.map(ByteFormatter.string) ?? "Unavailable")
                            metricRow("Memory allocated", stats.allocatedMemoryBytes.map(ByteFormatter.string) ?? "Unavailable")
                            metricRow("GPU cores", stats.coreCount?.formatted() ?? "Unavailable")
                        }
                        .padding(.top, 6)
                    }
                }

                if stats.devices.isEmpty {
                    ContentUnavailableView(
                        "No Metal GPU Found",
                        systemImage: "display",
                        description: Text("Metal did not return an available GPU device.")
                    )
                } else {
                    ForEach(stats.devices) { device in
                        deviceCard(device)
                    }
                }

                if let source = stats.sourceDescription {
                    Text(source)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.utilizationHistory.isEmpty {
                    GPUHistoryChart(history: viewModel.utilizationHistory)
                        .frame(height: 220)
                }
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private func utilizationStatus(_ availability: MetricAvailability<Double>) -> some View {
        GroupBox("System utilization") {
            switch availability {
            case .available(let value):
                Text(value.formatted(.percent.precision(.fractionLength(1))))
                    .font(.title2.monospacedDigit())
            case .unavailable(let reason):
                unavailableStatus("Unavailable", reason: reason)
            case .unsupported(let reason):
                unavailableStatus("Unsupported", reason: reason)
            }
        }
    }

    private func unavailableStatus(_ title: String, reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(reason).foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private func deviceCard(_ device: GPUDeviceInfo) -> some View {
        GroupBox(device.name) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                deviceRow("Unified memory", device.hasUnifiedMemory)
                deviceRow("Low power", device.isLowPower)
                deviceRow("Removable", device.isRemovable)
                deviceRow("Headless", device.isHeadless)
                GridRow {
                    Text("Registry ID")
                    Text(String(device.registryID)).monospacedDigit()
                }
            }
            .padding(.top, 6)
        }
    }

    private func deviceRow(_ label: String, _ value: Bool) -> some View {
        GridRow {
            Text(label)
            Text(value ? "Yes" : "No")
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
            Text(value).monospacedDigit()
        }
    }
}

private struct GPUHistoryChart: View {
    let history: [(timestamp: Date, utilization: Double)]

    var body: some View {
        GroupBox("GPU history") {
            Chart(Array(history.enumerated()), id: \.offset) { entry in
                LineMark(
                    x: .value("Time", entry.element.timestamp),
                    y: .value("Utilization", entry.element.utilization)
                )
            }
            .chartYScale(domain: 0...1)
            .accessibilityLabel("GPU utilization history")
        }
    }
}
