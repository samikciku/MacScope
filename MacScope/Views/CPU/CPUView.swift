import SwiftUI

struct CPUView: View {
    @ObservedObject var viewModel: CPUViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Sampling processor statistics…")
            case .failed(let message):
                ContentUnavailableView(
                    "CPU Statistics Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let stats):
                cpuContent(stats)
            }
        }
        .navigationTitle("CPU")
    }

    private func cpuContent(_ stats: CPUStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox("Overall") {
                    VStack(alignment: .leading, spacing: 12) {
                        utilizationRow("Usage", stats.totalUsage)
                        utilizationRow("User", stats.userUsage)
                        utilizationRow("System", stats.systemUsage)
                        utilizationRow("Idle", stats.idleUsage)
                    }
                    .padding(.top, 8)
                }

                GroupBox("Logical cores") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180), spacing: 16)],
                        spacing: 14
                    ) {
                        ForEach(Array(stats.perCoreUsage.enumerated()), id: \.offset) { index, usage in
                            utilizationRow("Core \(index + 1)", usage)
                        }
                    }
                    .padding(.top, 8)
                }

                CPUHistoryChart(history: viewModel.history)
                    .frame(height: 240)
            }
            .padding(24)
        }
    }

    private func utilizationRow(_ label: String, _ usage: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                Spacer()
                Text(usage.formatted(.percent.precision(.fractionLength(1))))
                    .monospacedDigit()
            }
            ProgressView(value: usage, total: 1)
                .accessibilityLabel(label)
                .accessibilityValue(usage.formatted(.percent.precision(.fractionLength(1))))
        }
    }
}
