import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var memoryViewModel: MemoryViewModel
    @ObservedObject var cpuViewModel: CPUViewModel
    @ObservedObject var processesViewModel: ProcessesViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MacScope")
                .font(.headline)

            HStack(spacing: 20) {
                status("Memory", value: memorySummary, icon: "memorychip")
                status("CPU", value: cpuSummary, icon: "cpu")
            }

            Divider()
            ranking("Top memory", processes: topMemory) {
                ByteFormatter.string(fromByteCount: $0.residentBytes)
            }
            ranking("Top CPU", processes: topCPU) {
                ($0.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1)))
            }

            Divider()
            HStack {
                Button("Open MacScope") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func status(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    private func ranking(
        _ title: String,
        processes: [ProcessSnapshot],
        value: @escaping (ProcessSnapshot) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if processes.isEmpty {
                Text("Collecting…").foregroundStyle(.secondary)
            } else {
                ForEach(processes) { process in
                    HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(process.name).lineLimit(1)
                                Text(process.owner ?? "Unknown").font(.caption2).foregroundStyle(.secondary)
                            }
                        Spacer()
                        Text(value(process)).monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var memorySummary: String {
        guard case .loaded(let stats) = memoryViewModel.state else { return "Unavailable" }
        return ByteFormatter.string(fromByteCount: stats.usedBytes)
    }

    private var cpuSummary: String {
        guard case .loaded(let stats) = cpuViewModel.state else { return "Unavailable" }
        return stats.totalUsage.formatted(.percent.precision(.fractionLength(1)))
    }

    private var snapshots: [ProcessSnapshot] {
        guard case .loaded(let values) = processesViewModel.state else { return [] }
        return values
    }

    private var topMemory: [ProcessSnapshot] {
        Array(snapshots.sorted { $0.residentBytes > $1.residentBytes }.prefix(3))
    }

    private var topCPU: [ProcessSnapshot] {
        Array(snapshots.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(3))
    }
}
