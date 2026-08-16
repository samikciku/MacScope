import SwiftUI

struct EnergyView: View {
    @ObservedObject var viewModel: ProcessesViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Collecting process energy data…")
            case .failed(let message):
                ContentUnavailableView("Process Energy Unavailable", systemImage: "bolt.slash", description: Text(message))
            case .loaded(let processes):
                table(processes)
            }
        }
        .navigationTitle("Energy")
    }

    private func table(_ processes: [ProcessSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Measured public process counters; this is not Apple's Energy Impact metric.")
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 12)
            Table(sorted(processes)) {
                TableColumn("Process") { process in
                    VStack(alignment: .leading) {
                        Text(process.name).lineLimit(1)
                        Text("PID \(process.pid)").font(.caption).foregroundStyle(.secondary)
                    }
                }.width(min: 160, ideal: 240)
                TableColumn("User") { process in
                    Text(process.owner ?? "Unknown").lineLimit(1)
                }.width(min: 90, ideal: 120)
                TableColumn("Power") { process in
                    Text(power(process.estimatedPowerWatts)).monospacedDigit()
                }.width(min: 80, ideal: 100)
                TableColumn("Wakeups/s") { process in
                    Text(number(process.wakeupsPerSecond)).monospacedDigit()
                }.width(min: 80, ideal: 100)
                TableColumn("Disk read/s") { process in
                    Text(rate(process.diskReadBytesPerSecond)).monospacedDigit()
                }.width(min: 90, ideal: 110)
                TableColumn("Disk write/s") { process in
                    Text(rate(process.diskWriteBytesPerSecond)).monospacedDigit()
                }.width(min: 90, ideal: 110)
                TableColumn("CPU") { process in
                    Text(process.cpuPercent / 100, format: .percent.precision(.fractionLength(1))).monospacedDigit()
                }.width(min: 65, ideal: 80)
            }
        }
        .padding(.top, 10)
        .accessibilityLabel("Measured per-process energy and activity counters")
    }

    private func sorted(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        processes.sorted {
            ($0.estimatedPowerWatts ?? -1, $0.wakeupsPerSecond ?? -1, $0.cpuPercent)
                > ($1.estimatedPowerWatts ?? -1, $1.wakeupsPerSecond ?? -1, $1.cpuPercent)
        }
    }

    private func power(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "—" }
        return value.formatted(.number.precision(.fractionLength(3))) + " W"
    }

    private func number(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(1))) ?? "—"
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "—" }
        return ByteFormatter.string(fromByteCount: UInt64(value)) + "/s"
    }
}
