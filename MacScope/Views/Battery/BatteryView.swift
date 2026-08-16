import Charts
import SwiftUI

struct BatteryView: View {
    @ObservedObject var viewModel: BatteryViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Reading battery information…")
            case .unavailable(let reason):
                ContentUnavailableView("Battery Information Unavailable", systemImage: "battery.0percent", description: Text(reason))
            case .unsupported(let reason):
                ContentUnavailableView("No Internal Battery", systemImage: "desktopcomputer", description: Text(reason))
            case .loaded(let stats):
                content(stats)
            }
        }
        .navigationTitle("Battery")
    }

    private func content(_ stats: BatteryStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox(stats.name) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProgressView(value: stats.chargeFraction)
                            .tint(stats.chargeFraction <= 0.2 ? .red : .green)
                        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                            row("Charge", stats.chargeFraction.formatted(.percent.precision(.fractionLength(0))))
                            row("Power source", stats.powerSource.rawValue)
                            row("Status", stats.isCharging ? "Charging" : "Not charging")
                            optionalRow("Time remaining", minutes(stats.timeRemainingMinutes))
                            optionalRow("Time to full", minutes(stats.timeToFullMinutes))
                            optionalRow("Health", stats.health)
                            optionalRow("Capacity health", stats.healthFraction?.formatted(.percent.precision(.fractionLength(0))))
                            optionalRow("Power adapter", stats.adapterWatts.map { "\($0) W" })
                        }
                    }.padding(.top, 8)
                }

                GroupBox("Charge history") {
                    Chart(viewModel.history, id: \.timestamp) { sample in
                        LineMark(x: .value("Time", sample.timestamp), y: .value("Charge", sample.chargeFraction))
                    }
                    .chartYScale(domain: 0...1)
                    .chartYAxis { AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(100)) }
                    .frame(height: 220)
                    .accessibilityLabel("Battery charge history")
                }

                Text("Battery values come from public IOKit power-source keys. Cycle count is omitted because it is not part of this API's public power-source dictionary contract.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label); Text(value).monospacedDigit().textSelection(.enabled) }
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func optionalRow(_ label: String, _ value: String?) -> some View {
        if let value { row(label, value) }
    }

    private func minutes(_ value: Int?) -> String? {
        guard let value else { return nil }
        return Duration.seconds(value * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
