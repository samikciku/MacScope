import Foundation

@MainActor
final class MemoryActionCoordinator: ObservableObject {
    @Published private(set) var report: MemoryReclaimReport?
    @Published private(set) var isMeasuring = false

    private let memoryViewModel: MemoryViewModel
    private let processesViewModel: ProcessesViewModel

    init(memoryViewModel: MemoryViewModel, processesViewModel: ProcessesViewModel) {
        self.memoryViewModel = memoryViewModel
        self.processesViewModel = processesViewModel
    }

    func terminate(_ process: ProcessSnapshot) async {
        await measure(targetName: process.name, estimate: process.residentBytes) {
            await processesViewModel.terminate(process)
        }
    }

    func terminate(_ group: ApplicationProcessGroup, estimatedResidentBytes: UInt64) async {
        await measure(targetName: group.name, estimate: estimatedResidentBytes) {
            await processesViewModel.terminate(group)
        }
    }

    func terminate(_ groups: [ApplicationProcessGroup], estimatedResidentBytes: UInt64) async {
        guard !groups.isEmpty else { return }
        let targetName = groups.count == 1 ? groups[0].name : "\(groups.count) selected applications"
        await measure(targetName: targetName, estimate: estimatedResidentBytes) {
            var results: [ProcessActionResult] = []
            for group in groups {
                results.append(await self.processesViewModel.terminate(group))
            }
            let completed = results.filter { $0.outcome == .completed }.count
            let stillRunning = results.filter { $0.outcome == .stillRunning }.count
            let failed = results.count - completed - stillRunning
            let outcome: ProcessActionResult.Outcome = failed > 0
                ? .failed
                : (stillRunning > 0 ? .stillRunning : .completed)
            return ProcessActionResult(
                target: targetName,
                action: .quitApplication,
                outcome: outcome,
                message: "Quit \(completed) of \(results.count) selected applications."
                    + (stillRunning > 0 ? " \(stillRunning) still running." : "")
                    + (failed > 0 ? " \(failed) could not be quit." : "")
            )
        }
    }

    private func measure(
        targetName: String,
        estimate: UInt64,
        action: () async -> ProcessActionResult
    ) async {
        guard !isMeasuring else { return }
        let before = currentStats
        isMeasuring = true
        report = nil
        let actionResult = await action()

        guard actionResult.outcome == .completed else {
            isMeasuring = false
            return
        }

        guard let before else {
            isMeasuring = false
            return
        }
        try? await Task.sleep(for: .seconds(2))
        await memoryViewModel.refresh()
        if let after = currentStats {
            report = MemoryReclaimReport(
                targetName: targetName,
                estimatedResidentBytes: estimate,
                before: before,
                after: after
            )
        }
        isMeasuring = false
    }

    private var currentStats: MemoryStats? {
        guard case .loaded(let stats) = memoryViewModel.state else { return nil }
        return stats
    }
}
