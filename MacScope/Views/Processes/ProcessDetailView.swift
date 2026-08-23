import SwiftUI

struct ProcessDetailView: View {
    let identity: ProcessSnapshot.Identity
    @ObservedObject var viewModel: ProcessesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsTerminate = false
    @State private var confirmsForceQuit = false
    @State private var connectionInspection: ProcessConnectionInspection = .loading
    @State private var argumentInspection: ProcessLaunchArgumentsInspection = .loading
    @State private var codeSigningInfo: ProcessCodeSigningInfo?
    @State private var codeSigningLoaded = false
    private let connectionInspector = ProcessConnectionInspector()
    private let argumentInspector = ProcessArgumentInspector()

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
                    row("Code signature", codeSigningLoaded ? codeSigningInfo?.validation.rawValue ?? "Unavailable" : "Loading…")
                    row("Signing identifier", codeSigningLoaded ? codeSigningInfo?.signingIdentifier ?? "Unavailable" : "Loading…")
                    row("Developer team", codeSigningLoaded ? codeSigningInfo?.teamIdentifier ?? "Unavailable" : "Loading…")
                    row("Executable", process.executablePath ?? "Unavailable")
                }
                .textSelection(.enabled)

                argumentsSection(process)
                historySection
                connectionsSection(process)
                if let result = viewModel.lastActionResult {
                    ProcessActionResultBanner(result: result) { viewModel.clearActionResult() }
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
        .task(id: process.identity) {
            codeSigningLoaded = false
            codeSigningInfo = await ProcessCodeSigningInspector.shared.information(
                executablePath: process.executablePath
            )
            guard !Task.isCancelled, viewModel.process(with: process.identity) != nil else { return }
            codeSigningLoaded = true
        }
        .task(id: process.identity) {
            connectionInspection = .loading
            do {
                let connections = try await connectionInspector.connections(for: process.pid)
                guard !Task.isCancelled, viewModel.process(with: process.identity) != nil else { return }
                connectionInspection = .loaded(connections)
            } catch {
                guard !Task.isCancelled else { return }
                connectionInspection = .unavailable(error.localizedDescription)
            }
        }
        .task(id: process.identity) {
            argumentInspection = .loading
            do {
                let result = try await argumentInspector.arguments(for: process.pid)
                guard !Task.isCancelled, viewModel.process(with: process.identity) != nil else { return }
                argumentInspection = .loaded(result.arguments, wasTruncated: result.wasTruncated)
            } catch {
                guard !Task.isCancelled else { return }
                argumentInspection = .unavailable(error.localizedDescription)
            }
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

    private func argumentsSection(_ process: ProcessSnapshot) -> some View {
        GroupBox("Launch arguments") {
            VStack(alignment: .leading, spacing: 8) {
                switch argumentInspection {
                case .loading:
                    ProgressView("Reading and redacting arguments…")
                case .unavailable(let reason):
                    Label(reason, systemImage: "eye.slash").foregroundStyle(.secondary)
                case .loaded(let arguments, let wasTruncated):
                    if arguments.isEmpty {
                        Text("No launch arguments are visible.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(arguments.enumerated()), id: \.offset) { index, argument in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(index.formatted()).foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                                Text(argument).textSelection(.enabled)
                            }
                            .font(.caption.monospaced())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Launch argument \(index): \(argument)")
                        }
                    }
                    if wasTruncated {
                        Text("Output was truncated to 64 arguments and 256 characters per argument.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Collected once for PID \(process.pid). Suspected credentials are replaced before display, but avoid sharing arguments without reviewing them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private func connectionsSection(_ process: ProcessSnapshot) -> some View {
        GroupBox("Open network connections") {
            VStack(alignment: .leading, spacing: 8) {
                switch connectionInspection {
                case .loading:
                    ProgressView("Inspecting connections…")
                case .unavailable(let reason):
                    Label(reason, systemImage: "network.slash").foregroundStyle(.secondary)
                case .loaded(let connections):
                    if connections.isEmpty {
                        Text("No visible listening sockets or active network connections.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(connections) { connection in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(connection.protocolName ?? connection.addressFamily)
                                    .frame(width: 55, alignment: .leading)
                                Text(connection.endpoint).textSelection(.enabled)
                                Spacer()
                                Text(connection.state ?? connection.fileDescriptor)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption.monospaced())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(connection.accessibilitySummary)
                        }
                        if connections.count == 200 {
                            Text("Showing the first 200 visible connections.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Collected on demand for PID \(process.pid); MacScope does not inspect packet contents.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
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
