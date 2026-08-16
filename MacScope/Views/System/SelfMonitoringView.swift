import SwiftUI

struct SelfMonitoringView: View {
    @ObservedObject var viewModel: ProcessesViewModel

    var body: some View {
        Group {
            if let process = viewModel.selfSnapshot {
                content(process)
            } else {
                ContentUnavailableView(
                    "MacScope Metrics Unavailable",
                    systemImage: "scope",
                    description: Text("The current MacScope process has not appeared in the latest process sample.")
                )
            }
        }
        .navigationTitle("MacScope")
    }

    private func content(_ process: ProcessSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MacScope’s own footprint")
                    .font(.title2.bold())
                Text("These values come from the same native process monitor and help enforce the project’s performance budget.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    selfMetric("Memory", ByteFormatter.string(fromByteCount: process.residentBytes), icon: "memorychip")
                    selfMetric("CPU", (process.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))), icon: "cpu")
                    selfMetric("Threads", process.threadCount.formatted(), icon: "square.stack.3d.up")
                }

                ProcessHistoryCharts(history: viewModel.history(for: process.identity))
                GroupBox("Sampling") {
                    LabeledContent("PID", value: process.pid.formatted())
                    LabeledContent("User", value: process.owner ?? "Unknown")
                    LabeledContent("Samples", value: viewModel.history(for: process.identity).count.formatted())
                }
            }
            .padding(24)
        }
    }

    private func selfMetric(_ title: String, _ value: String, icon: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).font(.headline)
                Text(value).font(.title2.monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
