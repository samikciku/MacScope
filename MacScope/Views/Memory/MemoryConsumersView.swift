import SwiftUI

enum MemoryConsumerQuery {
    static func apply(to snapshots: [ProcessSnapshot], searchText: String) -> [ProcessSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshots
            .filter {
                query.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || String($0.pid).contains(query)
                    || $0.owner?.localizedCaseInsensitiveContains(query) == true
            }
            .sorted {
                $0.residentBytes == $1.residentBytes
                    ? $0.pid < $1.pid
                    : $0.residentBytes > $1.residentBytes
            }
    }
}

struct MemoryConsumersView: View {
    let systemUsedBytes: UInt64
    @ObservedObject var processesViewModel: ProcessesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIdentity: ProcessSnapshot.Identity?
    @State private var pendingTermination: ProcessSnapshot?

    private var consumers: [ProcessSnapshot] {
        guard case .loaded(let snapshots) = processesViewModel.state else { return [] }
        return MemoryConsumerQuery.apply(to: snapshots, searchText: searchText)
    }

    private var attributedBytes: UInt64 {
        consumers.reduce(0) { partial, process in
            partial.addingReportingOverflow(process.residentBytes).overflow
                ? UInt64.max
                : partial + process.residentBytes
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            content
        }
        .navigationTitle("Memory Consumers")
        .searchable(text: $searchText, prompt: "Process, PID, or user")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: selectedProcess) { process in
            ProcessDetailView(identity: process.identity, viewModel: processesViewModel)
                .frame(minWidth: 560, minHeight: 580)
        }
        .alert("End Task?", isPresented: terminationPresented, presenting: pendingTermination) { process in
            Button("Cancel", role: .cancel) { pendingTermination = nil }
            Button("End Task", role: .destructive) {
                pendingTermination = nil
                Task { await processesViewModel.terminate(process) }
            }
        } message: { process in
            Text("End \(process.name) (PID \(process.pid))? Unsaved work may be lost. MacScope will send a normal termination request.")
        }
        .alert("Process Action", isPresented: actionMessagePresented) {
            Button("OK") { processesViewModel.actionMessage = nil }
        } message: {
            Text(processesViewModel.actionMessage ?? "")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("System used", systemImage: "memorychip")
                Spacer()
                Text(ByteFormatter.string(fromByteCount: systemUsedBytes)).monospacedDigit()
            }
            HStack {
                Text("Visible process resident memory")
                Spacer()
                Text(ByteFormatter.string(fromByteCount: attributedBytes)).monospacedDigit()
            }
            Text("Process totals do not equal system used memory because macOS also uses RAM for the kernel, wired/compressed memory, shared pages, and caches. Ending a task can lose unsaved work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        switch processesViewModel.state {
        case .loading:
            ProgressView("Reading process memory…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(
                "Process Memory Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded:
            if consumers.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                Table(consumers, selection: $selectedIdentity) {
                    TableColumn("Process") { process in
                        Button {
                            selectedIdentity = process.identity
                        } label: {
                            HStack(spacing: 8) {
                                ProcessIconLoader.shared.image(for: process.executablePath)
                                    .resizable().frame(width: 20, height: 20)
                                Text(process.name).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open process details")
                    }
                    .width(min: 180, ideal: 260)

                    TableColumn("Memory") { process in
                        Text(ByteFormatter.string(fromByteCount: process.residentBytes))
                            .monospacedDigit()
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("PID") { process in
                        Text(process.pid.formatted()).monospacedDigit()
                    }
                    .width(min: 60, ideal: 75)

                    TableColumn("User") { process in
                        Text(process.owner ?? "—").lineLimit(1)
                    }
                    .width(min: 100, ideal: 130)

                    TableColumn("End Task") { process in
                        terminationButton(process)
                    }
                    .width(min: 90, ideal: 105)
                }
                .accessibilityLabel("Processes sorted by memory usage")
            }
        }
    }

    private var selectedProcess: Binding<ProcessSnapshot?> {
        Binding(
            get: { selectedIdentity.flatMap(processesViewModel.process(with:)) },
            set: { selectedIdentity = $0?.identity }
        )
    }

    private var terminationPresented: Binding<Bool> {
        Binding(
            get: { pendingTermination != nil },
            set: { if !$0 { pendingTermination = nil } }
        )
    }

    private var actionMessagePresented: Binding<Bool> {
        Binding(
            get: { processesViewModel.actionMessage != nil },
            set: { if !$0 { processesViewModel.actionMessage = nil } }
        )
    }

    @ViewBuilder
    private func terminationButton(_ process: ProcessSnapshot) -> some View {
        switch processesViewModel.terminationDecision(for: process) {
        case .allowed:
            Button("End Task…", role: .destructive) { pendingTermination = process }
                .buttonStyle(.borderless)
                .accessibilityLabel("End task \(process.name), PID \(process.pid)")
        case .denied(let reason):
            Button("Protected") {}
                .buttonStyle(.borderless)
                .disabled(true)
                .help(reason)
                .accessibilityHint(reason)
        }
    }
}
