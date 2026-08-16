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

private enum MemoryConsumerFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case suggestions = "Suggestions"
    case active = "Active"
    case protected = "Protected"
    var id: Self { self }
}

private enum MemoryConsumerPresentation: String, CaseIterable, Identifiable {
    case applications = "Applications"
    case processes = "Processes"
    var id: Self { self }
}

struct MemoryConsumersView: View {
    let systemUsedBytes: UInt64
    @ObservedObject var memoryViewModel: MemoryViewModel
    @ObservedObject var processesViewModel: ProcessesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIdentity: ProcessSnapshot.Identity?
    @State private var pendingTermination: ProcessSnapshot?
    @State private var pendingGroupTermination: ApplicationProcessGroup?
    @State private var filter: MemoryConsumerFilter = .all
    @State private var presentation: MemoryConsumerPresentation = .applications
    @State private var reclaimReport: MemoryReclaimReport?
    @State private var isMeasuringReclaim = false

    private var consumers: [ProcessSnapshot] {
        guard case .loaded(let snapshots) = processesViewModel.state else { return [] }
        return MemoryConsumerQuery.apply(to: snapshots, searchText: searchText).filter { process in
            switch filter {
            case .all: true
            case .suggestions: assessment(for: process).classification == .lowerImpact
            case .active: assessment(for: process).classification == .active
            case .protected: assessment(for: process).classification == .protected
            }
        }
    }

    private var groups: [ApplicationProcessGroup] {
        processesViewModel.applicationGroups
            .filter { group in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                return query.isEmpty
                    || group.name.localizedCaseInsensitiveContains(query)
                    || group.processes.contains {
                        $0.name.localizedCaseInsensitiveContains(query)
                            || String($0.pid).contains(query)
                            || $0.owner?.localizedCaseInsensitiveContains(query) == true
                    }
            }
            .filter { group in
                let classification = assessment(for: group).classification
                return switch filter {
                case .all: true
                case .suggestions: classification == .lowerImpact
                case .active: classification == .active
                case .protected: classification == .protected
                }
            }
            .sorted {
                $0.residentBytes == $1.residentBytes
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.residentBytes > $1.residentBytes
            }
    }

    private var attributedBytes: UInt64 {
        let values = presentation == .applications ? groups.map(\.residentBytes) : consumers.map(\.residentBytes)
        return values.reduce(0) { partial, bytes in
            partial.addingReportingOverflow(bytes).overflow
                ? UInt64.max
                : partial + bytes
        }
    }

    private var suggestedBytes: UInt64 {
        let values: [UInt64] = presentation == .applications
            ? groups.compactMap { assessment(for: $0).classification == .lowerImpact ? assessment(for: $0).estimatedResidentBytes : nil }
            : consumers.compactMap { assessment(for: $0).classification == .lowerImpact ? $0.residentBytes : nil }
        return values.reduce(0) { partial, bytes in
            let result = partial.addingReportingOverflow(bytes)
            return result.overflow ? UInt64.max : result.partialValue
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
                Task { await terminateAndMeasure(process) }
            }
        } message: { process in
            Text("End \(process.name) (PID \(process.pid))? Unsaved work may be lost. MacScope will send a normal termination request.")
        }
        .alert("End Application Tasks?", isPresented: groupTerminationPresented, presenting: pendingGroupTermination) { group in
            Button("Cancel", role: .cancel) { pendingGroupTermination = nil }
            Button("End All Tasks", role: .destructive) {
                pendingGroupTermination = nil
                Task { await terminateAndMeasure(group) }
            }
        } message: { group in
            let eligible = processesViewModel.terminableProcesses(in: group).count
            let protected = group.processes.count - eligible
            Text("End \(eligible) process(es) in \(group.name)? Unsaved work may be lost. MacScope sends normal termination requests.\(protected > 0 ? " \(protected) protected process(es) will be skipped." : "")")
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
                Text(ByteFormatter.string(fromByteCount: currentMemoryStats?.usedBytes ?? systemUsedBytes)).monospacedDigit()
            }
            HStack {
                Text("Visible process resident memory")
                Spacer()
                Text(ByteFormatter.string(fromByteCount: attributedBytes)).monospacedDigit()
            }
            HStack {
                Text("Lower-impact candidates shown")
                Spacer()
                Text(ByteFormatter.string(fromByteCount: suggestedBytes)).monospacedDigit()
            }
            if isMeasuringReclaim {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Measuring memory after termination…")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let report = reclaimReport {
                reclaimSummary(report)
            }
            Picker("Display", selection: $presentation) {
                ForEach(MemoryConsumerPresentation.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Picker("Classification", selection: $filter) {
                ForEach(MemoryConsumerFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
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
            if presentation == .applications, groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if presentation == .processes, consumers.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if presentation == .applications {
                groupList
            } else {
                processTable
            }
        }
    }

    private var groupList: some View {
        List(groups) { group in
            DisclosureGroup {
                ForEach(group.processes) { process in
                    HStack(spacing: 10) {
                        ProcessIconLoader.shared.image(for: process.executablePath)
                            .resizable().frame(width: 18, height: 18)
                        Button(process.name) { selectedIdentity = process.identity }
                            .buttonStyle(.plain)
                        Text("PID \(process.pid) · \(process.owner ?? "Unknown user")")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteFormatter.string(fromByteCount: process.residentBytes)).monospacedDigit()
                        assessmentLabel(assessment(for: process))
                        terminationButton(process)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    ProcessIconLoader.shared.image(for: group.applicationPath)
                        .resizable().frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).fontWeight(.medium)
                        Text("\(group.processes.count) processes")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ByteFormatter.string(fromByteCount: group.residentBytes)).monospacedDigit()
                    assessmentLabel(assessment(for: group))
                    groupTerminationButton(group)
                }
            }
        }
        .accessibilityLabel("Applications sorted by memory usage")
    }

    private var processTable: some View {
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

                    TableColumn("Assessment") { process in
                        assessmentLabel(assessment(for: process))
                    }
                    .width(min: 145, ideal: 180)

                    TableColumn("End Task") { process in
                        terminationButton(process)
                    }
                    .width(min: 90, ideal: 105)
        }
        .accessibilityLabel("Processes sorted by memory usage")
    }

    private func assessment(for process: ProcessSnapshot) -> MemoryReclaimAssessment {
        MemoryReclaimClassifier.assess(
            process,
            history: processesViewModel.history(for: process.identity),
            terminationDecision: processesViewModel.terminationDecision(for: process)
        )
    }

    private func assessment(for group: ApplicationProcessGroup) -> MemoryReclaimAssessment {
        MemoryReclaimClassifier.assessGroup(
            name: group.name,
            assessments: group.processes.map(assessment(for:))
        )
    }

    private func terminateAndMeasure(_ process: ProcessSnapshot) async {
        guard let before = currentMemoryStats else {
            await processesViewModel.terminate(process)
            return
        }
        isMeasuringReclaim = true
        reclaimReport = nil
        let estimate = process.residentBytes
        await processesViewModel.terminate(process)
        await finishMeasurement(target: process.name, estimate: estimate, before: before)
    }

    private func terminateAndMeasure(_ group: ApplicationProcessGroup) async {
        guard let before = currentMemoryStats else {
            await processesViewModel.terminate(group)
            return
        }
        isMeasuringReclaim = true
        reclaimReport = nil
        let estimate = assessment(for: group).estimatedResidentBytes
        await processesViewModel.terminate(group)
        await finishMeasurement(target: group.name, estimate: estimate, before: before)
    }

    private func finishMeasurement(target: String, estimate: UInt64, before: MemoryStats) async {
        try? await Task.sleep(for: .seconds(2))
        await memoryViewModel.refresh()
        if let after = currentMemoryStats {
            reclaimReport = MemoryReclaimReport(
                targetName: target,
                estimatedResidentBytes: estimate,
                before: before,
                after: after
            )
        }
        isMeasuringReclaim = false
    }

    private var currentMemoryStats: MemoryStats? {
        guard case .loaded(let stats) = memoryViewModel.state else { return nil }
        return stats
    }

    private func reclaimSummary(_ report: MemoryReclaimReport) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("After ending \(report.targetName)").font(.caption).fontWeight(.semibold)
            HStack {
                Text("Estimated resident")
                Spacer()
                Text(ByteFormatter.string(fromByteCount: report.estimatedResidentBytes)).monospacedDigit()
            }
            HStack {
                Text("Available change")
                Spacer()
                Text(signedBytes(report.availableChange)).monospacedDigit()
            }
            HStack {
                Text("Free / purgeable change")
                Spacer()
                Text("\(signedBytes(report.freeChange)) / \(signedBytes(report.purgeableChange))")
                    .monospacedDigit()
            }
            Text(report.explanation).font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func signedBytes(_ value: Int64) -> String {
        let magnitude = value == .min ? UInt64.max : UInt64(abs(value))
        return "\(value >= 0 ? "+" : "−")\(ByteFormatter.string(fromByteCount: magnitude))"
    }

    private func assessmentLabel(_ assessment: MemoryReclaimAssessment) -> some View {
        Label(assessment.classification.rawValue, systemImage: assessment.classification.systemImage)
            .lineLimit(1)
            .frame(minWidth: 145, alignment: .leading)
            .help(assessment.reason)
            .accessibilityLabel("\(assessment.classification.rawValue). \(assessment.reason)")
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

    private var groupTerminationPresented: Binding<Bool> {
        Binding(
            get: { pendingGroupTermination != nil },
            set: { if !$0 { pendingGroupTermination = nil } }
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

    @ViewBuilder
    private func groupTerminationButton(_ group: ApplicationProcessGroup) -> some View {
        let count = processesViewModel.terminableProcesses(in: group).count
        if count > 0 {
            Button("End All…", role: .destructive) { pendingGroupTermination = group }
                .buttonStyle(.borderless)
                .help("End \(count) terminable process(es) in \(group.name)")
        } else {
            Button("Protected") {}
                .buttonStyle(.borderless)
                .disabled(true)
                .help("This group has no terminable processes.")
        }
    }
}
