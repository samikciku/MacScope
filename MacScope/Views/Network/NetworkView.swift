import Charts
import SwiftUI

struct NetworkView: View {
    @ObservedObject var viewModel: NetworkViewModel
    @ObservedObject var processesViewModel: ProcessesViewModel
    @State private var pendingTermination: ProcessSnapshot?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Reading network interfaces…")
            case .failed(let message):
                ContentUnavailableView("Network Statistics Unavailable", systemImage: "network.slash", description: Text(message))
            case .loaded(let stats):
                content(stats)
            }
        }
        .navigationTitle("Network")
        .alert("End Network Task?", isPresented: terminationConfirmationPresented, presenting: pendingTermination) { process in
            Button("Cancel", role: .cancel) { pendingTermination = nil }
            Button("End Task", role: .destructive) {
                pendingTermination = nil
                Task { await processesViewModel.terminate(process) }
            }
        } message: { process in
            Text("End \(process.name) (PID \(process.pid))? Unsaved work may be lost. MacScope will send a normal termination request.")
        }
        .alert("Process Action", isPresented: processActionMessagePresented) {
            Button("OK") { processesViewModel.actionMessage = nil }
        } message: {
            Text(processesViewModel.actionMessage ?? "")
        }
    }

    private func content(_ stats: NetworkStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Current activity") {
                    Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                        row("Download", rate(stats.downloadBytesPerSecond))
                        row("Upload", rate(stats.uploadBytesPerSecond))
                        row("Total received", ByteFormatter.string(fromByteCount: stats.totalReceivedBytes))
                        row("Total transmitted", ByteFormatter.string(fromByteCount: stats.totalTransmittedBytes))
                    }.padding(.top, 8)
                }

                GroupBox("Transfer history") {
                    Chart(viewModel.history, id: \.timestamp) { sample in
                        if let download = sample.downloadBytesPerSecond {
                            LineMark(x: .value("Time", sample.timestamp), y: .value("Bytes per second", download), series: .value("Direction", "Download"))
                                .foregroundStyle(by: .value("Direction", "Download"))
                        }
                        if let upload = sample.uploadBytesPerSecond {
                            LineMark(x: .value("Time", sample.timestamp), y: .value("Bytes per second", upload), series: .value("Direction", "Upload"))
                                .foregroundStyle(by: .value("Direction", "Upload"))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                    .frame(height: 220)
                    .accessibilityLabel("Network download and upload rates")
                }

                GroupBox("Active interfaces") {
                    if stats.interfaces.isEmpty {
                        Text("No active non-loopback interfaces were found.").foregroundStyle(.secondary)
                    } else {
                        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                            GridRow { Text("Interface").bold(); Text("Received").bold(); Text("Transmitted").bold() }
                            ForEach(stats.interfaces) { interface in
                                GridRow {
                                    Text(interface.name).monospaced()
                                    Text(ByteFormatter.string(fromByteCount: interface.receivedBytes)).monospacedDigit()
                                    Text(ByteFormatter.string(fromByteCount: interface.transmittedBytes)).monospacedDigit()
                                }
                            }
                        }.padding(.top, 8)
                    }
                }

                processTraffic

                Text("Interface counters use public link-layer statistics. Per-process attribution comes from macOS nettop totals and calculated deltas; MacScope does not inspect packet contents or remote hosts.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 800, alignment: .leading)
        }
    }

    @ViewBuilder
    private var processTraffic: some View {
        GroupBox("Traffic by process") {
            switch viewModel.processTraffic {
            case .available(let usage):
                if usage.isEmpty {
                    ContentUnavailableView("No Process Traffic", systemImage: "network")
                        .frame(minHeight: 160)
                } else {
                    Table(usage) {
                        TableColumn("Process") { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).lineLimit(1)
                                Text("PID \(item.pid)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .width(min: 170, ideal: 230)
                        TableColumn("User") { item in
                            Text(processesViewModel.process(withPID: item.pid)?.owner ?? "Unknown")
                                .lineLimit(1)
                        }
                        .width(min: 90, ideal: 115)
                        TableColumn("Download/s") { item in Text(rate(item.downloadBytesPerSecond)).monospacedDigit() }
                            .width(min: 100, ideal: 115)
                        TableColumn("Upload/s") { item in Text(rate(item.uploadBytesPerSecond)).monospacedDigit() }
                            .width(min: 100, ideal: 115)
                        TableColumn("Received") { item in Text(ByteFormatter.string(fromByteCount: item.totalReceivedBytes)).monospacedDigit() }
                            .width(min: 90, ideal: 105)
                        TableColumn("Sent") { item in Text(ByteFormatter.string(fromByteCount: item.totalSentBytes)).monospacedDigit() }
                            .width(min: 90, ideal: 105)
                        TableColumn("Action") { item in terminationButton(for: item) }
                            .width(min: 90, ideal: 105)
                    }
                    .frame(height: 330)
                }
            case .unavailable(let reason), .unsupported(let reason):
                ContentUnavailableView(
                    "Per-Process Traffic Unavailable",
                    systemImage: "network.slash",
                    description: Text(reason)
                )
                .frame(minHeight: 160)
            }
        }
    }

    @ViewBuilder
    private func terminationButton(for usage: ProcessNetworkUsage) -> some View {
        if let process = processesViewModel.process(withPID: usage.pid) {
            switch processesViewModel.terminationDecision(for: process) {
            case .allowed:
                Button("End Task…", role: .destructive) { pendingTermination = process }
                    .buttonStyle(.borderless)
            case .denied(let reason):
                Button("Protected") {}.buttonStyle(.borderless).disabled(true).help(reason)
            }
        } else {
            Button("Exited") {}.buttonStyle(.borderless).disabled(true)
        }
    }

    private var terminationConfirmationPresented: Binding<Bool> {
        Binding(get: { pendingTermination != nil }, set: { if !$0 { pendingTermination = nil } })
    }

    private var processActionMessagePresented: Binding<Bool> {
        Binding(get: { processesViewModel.actionMessage != nil }, set: { if !$0 { processesViewModel.actionMessage = nil } })
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label); Text(value).monospacedDigit().textSelection(.enabled) }
            .accessibilityElement(children: .combine)
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "Collecting…" }
        return "\(ByteFormatter.string(fromByteCount: UInt64(value)))/s"
    }
}
