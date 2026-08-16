import SwiftUI

struct ProcessDetailView: View {
    let identity: ProcessSnapshot.Identity
    @ObservedObject var viewModel: ProcessesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsTerminate = false
    @State private var confirmsForceQuit = false

    var body: some View {
        Group {
            if let process = viewModel.process(with: identity) {
                detail(process)
            } else {
                ContentUnavailableView(
                    "Process Ended",
                    systemImage: "checkmark.circle",
                    description: Text("This process is no longer running.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func detail(_ process: ProcessSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    ProcessIconLoader.shared.image(for: process.executablePath)
                        .resizable()
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text(process.name).font(.title2.bold())
                        Text("PID \(process.pid)").foregroundStyle(.secondary)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    row("Parent PID", process.parentPID?.formatted() ?? "Unavailable")
                    row("Resident memory", ByteFormatter.string(fromByteCount: process.residentBytes))
                    row("Virtual memory", process.virtualBytes.map(ByteFormatter.string) ?? "Unavailable")
                    row("CPU", (process.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))))
                    row("Measured power", process.estimatedPowerWatts.map { $0.formatted(.number.precision(.fractionLength(3))) + " W" } ?? "Unavailable")
                    row("Wakeups per second", process.wakeupsPerSecond?.formatted(.number.precision(.fractionLength(1))) ?? "Unavailable")
                    row("Disk read rate", byteRate(process.diskReadBytesPerSecond))
                    row("Disk write rate", byteRate(process.diskWriteBytesPerSecond))
                    row("Threads", process.threadCount.formatted())
                    row("Owner", process.owner ?? "Unavailable")
                    row("Architecture", process.architecture ?? "Unavailable")
                    row("Bundle identifier", process.bundleIdentifier ?? "Unavailable")
                    row("Executable", process.executablePath ?? "Unavailable")
                }
                .textSelection(.enabled)

                historySection
                if let message = viewModel.actionMessage {
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Process action: \(message)")
                }
                terminationSection(process)
            }
            .padding(24)
        }
        .navigationTitle(process.name)
        .alert("Terminate \(process.name)?", isPresented: $confirmsTerminate) {
            Button("Cancel", role: .cancel) {}
            Button("Terminate", role: .destructive) {
                Task { await viewModel.terminate(process) }
            }
        } message: {
            Text("PID \(process.pid) is using \(ByteFormatter.string(fromByteCount: process.residentBytes)). Unsaved work may be lost.")
        }
        .alert("Force Quit \(process.name)?", isPresented: $confirmsForceQuit) {
            Button("Cancel", role: .cancel) {}
            Button("Force Quit", role: .destructive) {
                Task { await viewModel.forceQuit(process) }
            }
        } message: {
            Text("This sends SIGKILL immediately. The process cannot save data or clean up first.")
        }
    }

    private var historySection: some View {
        let history = viewModel.history(for: identity)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(history.count) of 300 bounded samples")
                .foregroundStyle(.secondary)
            ProcessHistoryCharts(history: history)
        }
    }

    @ViewBuilder
    private func terminationSection(_ process: ProcessSnapshot) -> some View {
        GroupBox("Process control") {
            VStack(alignment: .leading, spacing: 10) {
                switch viewModel.terminationDecision(for: process) {
                case .allowed:
                    Button("Terminate…", role: .destructive) { confirmsTerminate = true }
                    if viewModel.forceQuitEligibleIdentity == identity {
                        Button("Force Quit…", role: .destructive) { confirmsForceQuit = true }
                    }
                case .denied(let reason):
                    Text(reason).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
            Text(value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func byteRate(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "Unavailable" }
        return ByteFormatter.string(fromByteCount: UInt64(value)) + "/s"
    }
}
