import Charts
import SwiftUI

struct ThermalView: View {
    @ObservedObject var viewModel: ThermalViewModel

    var body: some View {
        Group {
            if let stats = viewModel.stats {
                content(stats)
            } else {
                ProgressView("Reading thermal state…")
            }
        }
        .navigationTitle("Thermal")
    }

    private func content(_ stats: ThermalStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("System thermal pressure") {
                    Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                        GridRow {
                            Text("Current state")
                            Label(stats.state.title, systemImage: symbol(stats.state))
                                .foregroundStyle(color(stats.state))
                        }
                        row("Low Power Mode", stats.lowPowerModeEnabled ? "Enabled" : "Disabled")
                        row("CPU temperature", "Unavailable through public API")
                        row("GPU temperature", "Unavailable through public API")
                    }.padding(.top, 8)
                }

                GroupBox("Thermal-state history") {
                    Chart(viewModel.history, id: \.timestamp) { sample in
                        LineMark(x: .value("Time", sample.timestamp), y: .value("State", sample.state.rawValue))
                            .interpolationMethod(.stepEnd)
                    }
                    .chartYScale(domain: 0...3)
                    .chartYAxis {
                        AxisMarks(values: [0, 1, 2, 3]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let raw = value.as(Int.self), let state = ThermalStats.State(rawValue: raw) {
                                    Text(state.title)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .accessibilityLabel("System thermal-state history")
                }

                Text("macOS reports system-wide thermal pressure, not exact sensor temperatures, through this public API.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label); Text(value).textSelection(.enabled) }
            .accessibilityElement(children: .combine)
    }

    private func symbol(_ state: ThermalStats.State) -> String {
        state.rawValue >= ThermalStats.State.serious.rawValue ? "thermometer.high" : "thermometer.medium"
    }

    private func color(_ state: ThermalStats.State) -> Color {
        switch state {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}
