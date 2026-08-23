import SwiftUI

struct ProcessesView: View {
    @ObservedObject var viewModel: ProcessesViewModel
    @State private var pendingTermination: ProcessSnapshot?
    @State private var pendingGroupTermination: ApplicationProcessGroup?

    var body: some View {
        VStack(spacing: 0) {
            controls
            if let result = viewModel.lastActionResult {
                ProcessActionResultBanner(result: result) { viewModel.clearActionResult() }
                    .padding(.horizontal, 12).padding(.bottom, 8)
            }
            Divider()
            content
        }
        .navigationTitle("Processes")
        .searchable(text: $viewModel.searchText, prompt: "Process name or PID")
        .sheet(item: selectedProcessBinding) { process in
            ProcessDetailView(identity: process.identity, viewModel: viewModel)
                .frame(minWidth: 560, minHeight: 580)
        }
        .alert("End Task?", isPresented: terminationConfirmationPresented, presenting: pendingTermination) { process in
            Button("Cancel", role: .cancel) { pendingTermination = nil }
            Button("End Task", role: .destructive) {
                pendingTermination = nil
                Task { await viewModel.terminate(process) }
            }
        } message: { process in
            Text("End \(process.name) (PID \(process.pid))? Unsaved work may be lost. MacScope will send a normal termination request.")
        }
        .alert(groupAlertTitle, isPresented: groupTerminationConfirmationPresented, presenting: pendingGroupTermination) { group in
            Button("Cancel", role: .cancel) { pendingGroupTermination = nil }
            Button(group.applicationPath == nil ? "End All Tasks" : "Quit Application", role: .destructive) {
                pendingGroupTermination = nil
                Task { await viewModel.terminate(group) }
            }
        } message: { group in
            let eligible = viewModel.terminableProcesses(in: group).count
            let protected = group.processes.count - eligible
            if group.applicationPath == nil {
                Text("End \(eligible) \(eligible == 1 ? "process" : "processes") in \(group.name)? Unsaved work may be lost.\(protected > 0 ? " \(protected) protected processes will be skipped." : "")")
            } else {
                Text("Ask \(group.name) to quit normally? The application can prompt for unsaved work. If macOS cannot identify the running application, MacScope will take no action rather than silently fall back to process signals.")
            }
        }
    }

    private var groupAlertTitle: String {
        pendingGroupTermination?.applicationPath == nil ? "End All Tasks?" : "Quit Application?"
    }

    private var selectedProcessBinding: Binding<ProcessSnapshot?> {
        Binding(
            get: {
                guard let selection = viewModel.selection else { return nil }
                return viewModel.process(with: selection)
            },
            set: { newValue in viewModel.selection = newValue?.identity }
        )
    }

    private var terminationConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingTermination != nil },
            set: { if !$0 { pendingTermination = nil } }
        )
    }

    private var groupTerminationConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingGroupTermination != nil },
            set: { if !$0 { pendingGroupTermination = nil } }
        )
    }

    private var controls: some View {
        HStack {
            Picker("Presentation", selection: $viewModel.presentationMode) {
                ForEach(ProcessPresentationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Picker("Sort", selection: $viewModel.sortField) {
                ForEach(ProcessSortField.allCases) { field in
                    Text(field.title).tag(field)
                }
            }
            .frame(width: 150)

            Picker("Order", selection: $viewModel.sortOrder) {
                ForEach(ProcessSortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .frame(width: 170)

            Spacer()
            Text(countDescription)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Enumerating processes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(
                "Processes Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded:
            if isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if viewModel.presentationMode == .applications {
                applicationGroups
            } else if viewModel.presentationMode == .hierarchy {
                processHierarchy
            } else {
                processTable
            }
        }
    }

    private var countDescription: String {
        if viewModel.presentationMode == .applications {
            return "\(viewModel.visibleGroups.count) groups"
        } else if viewModel.presentationMode == .hierarchy {
            return "\(hierarchyCount) processes"
        }
        return "\(viewModel.visibleProcesses.count) processes"
    }

    private var isEmpty: Bool {
        switch viewModel.presentationMode {
        case .applications: viewModel.visibleGroups.isEmpty
        case .individual: viewModel.visibleProcesses.isEmpty
        case .hierarchy: viewModel.visibleHierarchy.isEmpty
        }
    }

    private var hierarchyCount: Int {
        func count(_ nodes: [ProcessTreeNode]) -> Int {
            nodes.reduce(0) { $0 + 1 + count($1.children) }
        }
        return count(viewModel.visibleHierarchy)
    }

    private var processHierarchy: some View {
        List {
            OutlineGroup(viewModel.visibleHierarchy, children: \.outlineChildren) { node in
                HStack(spacing: 10) {
                    Button {
                        viewModel.selection = node.process.identity
                    } label: {
                        ProcessIconLoader.shared.image(for: node.process.executablePath)
                            .resizable().frame(width: 18, height: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.process.name).lineLimit(1)
                            Text("PID \(node.process.pid) · user \(node.process.owner ?? "Unknown") · parent \(node.process.parentPID?.formatted() ?? "—")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(ByteFormatter.string(fromByteCount: node.process.residentBytes))
                            .monospacedDigit().frame(width: 90, alignment: .trailing)
                        Text((node.process.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))))
                            .monospacedDigit().frame(width: 70, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Open process details")
                    endTaskButton(node.process)
                }
                .contextMenu { processContextMenu(node.process) }
            }
        }
        .accessibilityLabel("Parent and child process hierarchy")
    }

    private var applicationGroups: some View {
        List(viewModel.visibleGroups) { group in
            DisclosureGroup {
                ForEach(group.processes) { process in
                    HStack(spacing: 10) {
                        Button {
                            viewModel.selection = process.identity
                        } label: {
                            ProcessIconLoader.shared.image(for: process.executablePath)
                                .resizable()
                                .frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.name).lineLimit(1)
                                Text("PID \(process.pid) · user \(process.owner ?? "Unknown")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(ByteFormatter.string(fromByteCount: process.residentBytes))
                                .monospacedDigit()
                                .frame(width: 90, alignment: .trailing)
                            Text((process.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))))
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open process details")
                        endTaskButton(process)
                    }
                    .contextMenu { processContextMenu(process) }
                }
            } label: {
                HStack(spacing: 10) {
                    ProcessIconLoader.shared.image(for: group.applicationPath)
                        .resizable()
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).fontWeight(.medium)
                        Text("\(group.processes.count) \(group.processes.count == 1 ? "process" : "processes") · \(groupUsers(group))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ByteFormatter.string(fromByteCount: group.residentBytes))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                    Text((group.cpuPercent / 100).formatted(.percent.precision(.fractionLength(1))))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                    endGroupTasksButton(group)
                }
                .contextMenu { groupContextMenu(group) }
            }
        }
        .accessibilityLabel("Applications and grouped processes")
    }

    private var processTable: some View {
        Table(viewModel.visibleProcesses, selection: $viewModel.selection) {
            TableColumn("Process") { process in
                HStack(spacing: 8) {
                    ProcessIconLoader.shared.image(for: process.executablePath)
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(process.name)
                        .lineLimit(1)
                }
                .help(process.executablePath ?? process.name)
            }
            .width(min: 180, ideal: 260)

            TableColumn("End Task") { process in
                endTaskButton(process)
            }
            .width(min: 88, ideal: 100)

            TableColumn("PID") { process in
                Text(process.pid.formatted())
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 75)

            TableColumn("Memory") { process in
                Text(ByteFormatter.string(fromByteCount: process.residentBytes))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110)

            TableColumn("CPU") { process in
                Text(process.cpuPercent / 100, format: .percent.precision(.fractionLength(1)))
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 85)

            TableColumn("Threads") { process in
                Text(process.threadCount.formatted())
                    .monospacedDigit()
            }
            .width(min: 65, ideal: 75)

            TableColumn("User") { process in
                Text(process.owner ?? "—")
                    .lineLimit(1)
            }
            .width(min: 90, ideal: 120)

        }
        .contextMenu(forSelectionType: ProcessSnapshot.Identity.self) { identities in
            if let identity = identities.first,
               let process = viewModel.process(with: identity) {
                processContextMenu(process)
            }
        }
        .accessibilityLabel("Running processes")
    }

    @ViewBuilder
    private func endTaskButton(_ process: ProcessSnapshot) -> some View {
        switch viewModel.terminationDecision(for: process) {
        case .allowed:
            Button("End Task…", role: .destructive) { pendingTermination = process }
                .buttonStyle(.borderless)
                .disabled(viewModel.processesBeingTerminated.contains(process.identity))
                .accessibilityLabel("End task \(process.name), PID \(process.pid)")
        case .denied(let reason):
            Button("Protected") {}
                .buttonStyle(.borderless)
                .disabled(true)
                .help(reason)
                .accessibilityHint(reason)
        }
    }

    @ViewBuilder
    private func processContextMenu(_ process: ProcessSnapshot) -> some View {
        switch viewModel.terminationDecision(for: process) {
        case .allowed:
            Button("End Task…", role: .destructive) { pendingTermination = process }
        case .denied(let reason):
            Button("Protected: \(reason)") {}
                .disabled(true)
        }
    }

    @ViewBuilder
    private func endGroupTasksButton(_ group: ApplicationProcessGroup) -> some View {
        let count = viewModel.terminableProcesses(in: group).count
        if count > 0 {
            Button(group.applicationPath == nil ? "End All…" : "Quit…", role: .destructive) { pendingGroupTermination = group }
                .buttonStyle(.borderless)
                .disabled(viewModel.groupsBeingTerminated.contains(group.id))
                .help(group.applicationPath == nil ? "End \(count) terminable process(es) in \(group.name)" : "Ask \(group.name) to quit normally")
                .accessibilityLabel(group.applicationPath == nil ? "End all tasks in \(group.name)" : "Quit application \(group.name)")
        } else {
            Button("Protected") {}
                .buttonStyle(.borderless)
                .disabled(true)
                .help("This group has no processes MacScope can safely terminate.")
        }
    }

    @ViewBuilder
    private func groupContextMenu(_ group: ApplicationProcessGroup) -> some View {
        let count = viewModel.terminableProcesses(in: group).count
        if count > 0 {
            Button(group.applicationPath == nil ? "End All Tasks…" : "Quit Application…", role: .destructive) { pendingGroupTermination = group }
        } else {
            Button("Protected Group") {}
                .disabled(true)
        }
    }

    private func groupUsers(_ group: ApplicationProcessGroup) -> String {
        let users = Set(group.processes.compactMap(\.owner)).sorted()
        if users.isEmpty { return "user unknown" }
        if users.count == 1 { return "user \(users[0])" }
        return "\(users.count) users"
    }
}
