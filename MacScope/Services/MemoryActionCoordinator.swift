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

    private func measure(
        targetName: String,
        estimate: UInt64,
        action: () async -> Void
    ) async {
        guard !isMeasuring else { return }
        let before = currentStats
        isMeasuring = true
        report = nil
        await action()

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
