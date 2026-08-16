import Foundation

enum ProcessSortField: String, CaseIterable, Identifiable, Sendable {
    case memory
    case cpu
    case name
    case pid

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum ProcessSortOrder: String, CaseIterable, Identifiable, Sendable {
    case descending
    case ascending

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum ProcessPresentationMode: String, CaseIterable, Identifiable, Sendable {
    case applications
    case individual
    case hierarchy

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum ProcessQuery {
    static func apply(
        to snapshots: [ProcessSnapshot],
        searchText: String,
        sortField: ProcessSortField,
        sortOrder: ProcessSortOrder
    ) -> [ProcessSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? snapshots : snapshots.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || String($0.pid).contains(query)
                || $0.bundleIdentifier?.localizedCaseInsensitiveContains(query) == true
                || $0.codeSigning?.signingIdentifier?.localizedCaseInsensitiveContains(query) == true
                || $0.codeSigning?.teamIdentifier?.localizedCaseInsensitiveContains(query) == true
        }

        return filtered.sorted { lhs, rhs in
            let ordered: Bool
            switch sortField {
            case .memory:
                ordered = lhs.residentBytes != rhs.residentBytes
                    ? lhs.residentBytes < rhs.residentBytes : lhs.pid < rhs.pid
            case .cpu:
                ordered = lhs.cpuPercent != rhs.cpuPercent
                    ? lhs.cpuPercent < rhs.cpuPercent : lhs.pid < rhs.pid
            case .name:
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                ordered = comparison != .orderedSame ? comparison == .orderedAscending : lhs.pid < rhs.pid
            case .pid:
                ordered = lhs.pid < rhs.pid
            }
            return sortOrder == .ascending ? ordered : !ordered
        }
    }
}

@MainActor
final class ProcessesViewModel: ObservableObject {
    private final class ProcessHistory {
        var samples = RingBuffer<ProcessResourceSample>(capacity: 300)
    }

    enum State: Equatable {
        case loading
        case loaded([ProcessSnapshot])
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var applicationGroups: [ApplicationProcessGroup] = []
    @Published var searchText = ""
    @Published var sortField: ProcessSortField = .memory
    @Published var sortOrder: ProcessSortOrder = .descending
    @Published var selection: ProcessSnapshot.Identity?
    @Published var presentationMode: ProcessPresentationMode = .applications
    @Published private(set) var forceQuitEligibleIdentity: ProcessSnapshot.Identity?
    @Published private(set) var lastActionResult: ProcessActionResult?
    @Published private(set) var processesBeingTerminated: Set<ProcessSnapshot.Identity> = []
    @Published private(set) var groupsBeingTerminated: Set<String> = []

    private let monitor: any ProcessMonitorProtocol
    private let terminationService: ProcessTerminationService
    private let terminationPolicy: ProcessTerminationPolicy
    private let applicationQuitService: ApplicationQuitService
    private var histories: [ProcessSnapshot.Identity: ProcessHistory] = [:]

    init(
        monitor: any ProcessMonitorProtocol = ProcessMonitor(),
        terminationService: ProcessTerminationService = ProcessTerminationService(),
        terminationPolicy: ProcessTerminationPolicy = ProcessTerminationPolicy(),
        applicationQuitService: ApplicationQuitService = ApplicationQuitService()
    ) {
        self.monitor = monitor
        self.terminationService = terminationService
        self.terminationPolicy = terminationPolicy
        self.applicationQuitService = applicationQuitService
    }

    var visibleProcesses: [ProcessSnapshot] {
        guard case .loaded(let snapshots) = state else { return [] }
        return ProcessQuery.apply(
            to: snapshots,
            searchText: searchText,
            sortField: sortField,
            sortOrder: sortOrder
        )
    }

    var visibleGroups: [ApplicationProcessGroup] {
        return ProcessGrouping.sorted(
            applicationGroups,
            searchText: searchText,
            sortField: sortField,
            sortOrder: sortOrder
        )
    }

    var visibleHierarchy: [ProcessTreeNode] {
        guard case .loaded(let snapshots) = state else { return [] }
        return ProcessHierarchy.forest(from: snapshots, searchText: searchText)
    }

    var selfSnapshot: ProcessSnapshot? {
        guard case .loaded(let snapshots) = state else { return nil }
        return snapshots.first { $0.pid == ProcessInfo.processInfo.processIdentifier }
    }

    func refresh() async {
        do {
            let snapshots = try await monitor.currentProcesses()
            appendHistory(from: snapshots)
            applicationGroups = ProcessGrouping.groups(from: snapshots)
            state = .loaded(snapshots)
            if let eligible = forceQuitEligibleIdentity,
               !snapshots.contains(where: { $0.identity == eligible }) {
                forceQuitEligibleIdentity = nil
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refreshContinuously(every interval: Duration = .seconds(2)) async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    func process(with identity: ProcessSnapshot.Identity) -> ProcessSnapshot? {
        guard case .loaded(let snapshots) = state else { return nil }
        return snapshots.first { $0.identity == identity }
    }

    func process(withPID pid: Int32) -> ProcessSnapshot? {
        guard case .loaded(let snapshots) = state else { return nil }
        return snapshots.first { $0.pid == pid }
    }

    func history(for identity: ProcessSnapshot.Identity) -> [ProcessResourceSample] {
        histories[identity].map { Array($0.samples) } ?? []
    }

    func terminationDecision(for process: ProcessSnapshot) -> ProcessTerminationDecision {
        terminationPolicy.decision(for: process)
    }

    func terminableProcesses(in group: ApplicationProcessGroup) -> [ProcessSnapshot] {
        group.processes.filter {
            if case .allowed = terminationPolicy.decision(for: $0) { return true }
            return false
        }
    }

    @discardableResult
    func terminate(_ process: ProcessSnapshot) async -> ProcessActionResult {
        guard !processesBeingTerminated.contains(process.identity) else {
            return result(process.name, .terminateProcess, .noAction, "An action is already in progress.")
        }
        processesBeingTerminated.insert(process.identity)
        defer { processesBeingTerminated.remove(process.identity) }
        do {
            try await terminationService.send(.terminate, to: process)
            try? await Task.sleep(for: .seconds(1))
            await refresh()
            if self.process(with: process.identity) != nil {
                forceQuitEligibleIdentity = process.identity
                return result(process.name, .terminateProcess, .stillRunning, "The normal termination request was sent, but the process is still running.")
            }
            return result(process.name, .terminateProcess, .completed, "The process exited after a normal termination request.")
        } catch {
            return result(process.name, .terminateProcess, .failed, error.localizedDescription)
        }
    }

    @discardableResult
    func terminate(_ group: ApplicationProcessGroup) async -> ProcessActionResult {
        guard !groupsBeingTerminated.contains(group.id) else {
            return result(group.name, .terminateGroup, .noAction, "An action is already in progress.")
        }
        groupsBeingTerminated.insert(group.id)
        defer { groupsBeingTerminated.remove(group.id) }
        let eligible = terminableProcesses(in: group)
        if GroupTerminationMode.mode(for: group) == .quitApplication {
            let requested = applicationQuitService.requestQuit(processes: eligible)
            guard requested > 0 else {
                return result(group.name, .quitApplication, .noAction, "macOS could not identify the running application, so no signal was sent.")
            }
            let exited = await waitForExit(eligible.map(\.identity), timeoutSeconds: 5)
            return exited
                ? result(group.name, .quitApplication, .completed, "The application exited after a normal quit request.")
                : result(group.name, .quitApplication, .stillRunning, "The application is still running. It may be showing an unsaved-work prompt or may have cancelled quit.")
        }
        var sent = 0
        var failed = 0

        for process in eligible {
            do {
                try await terminationService.send(.terminate, to: process)
                sent += 1
            } catch {
                failed += 1
            }
        }

        let protected = group.processes.count - eligible.count
        var parts = ["Sent termination requests to \(sent) \(sent == 1 ? "process" : "processes") in \(group.name)."]
        if protected > 0 { parts.append("Skipped \(protected) protected.") }
        if failed > 0 { parts.append("\(failed) had already exited or could not be terminated.") }
        try? await Task.sleep(for: .seconds(1))
        await refresh()
        let stillRunning = eligible.contains { process(with: $0.identity) != nil }
        return result(group.name, .terminateGroup, stillRunning ? .stillRunning : .completed, parts.joined(separator: " "))
    }

    @discardableResult
    func forceQuit(_ process: ProcessSnapshot) async -> ProcessActionResult {
        do {
            try await terminationService.send(.kill, to: process)
            forceQuitEligibleIdentity = nil
            await refresh()
            return result(process.name, .forceQuit, self.process(with: process.identity) == nil ? .completed : .stillRunning,
                          self.process(with: process.identity) == nil ? "The process exited." : "The process still appears in the latest sample.")
        } catch {
            return result(process.name, .forceQuit, .failed, error.localizedDescription)
        }
    }

    func clearActionResult() { lastActionResult = nil }

    private func waitForExit(_ identities: [ProcessSnapshot.Identity], timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            try? await Task.sleep(for: .seconds(1))
            await refresh()
            if identities.allSatisfy({ process(with: $0) == nil }) { return true }
        }
        return false
    }

    private func result(
        _ target: String, _ action: ProcessActionResult.Action,
        _ outcome: ProcessActionResult.Outcome, _ message: String
    ) -> ProcessActionResult {
        let value = ProcessActionResult(target: target, action: action, outcome: outcome, message: message)
        lastActionResult = value
        return value
    }

    private func appendHistory(from snapshots: [ProcessSnapshot]) {
        let activeIdentities = Set(snapshots.map(\.identity))
        histories = histories.filter { activeIdentities.contains($0.key) }
        for snapshot in snapshots {
            let history = histories[snapshot.identity] ?? ProcessHistory()
            history.samples.append(
                ProcessResourceSample(
                    timestamp: snapshot.timestamp,
                    residentBytes: snapshot.residentBytes,
                    cpuPercent: snapshot.cpuPercent
                )
            )
            histories[snapshot.identity] = history
        }
    }
}
