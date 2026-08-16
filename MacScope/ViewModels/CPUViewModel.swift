import Foundation

@MainActor
final class CPUViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(CPUStats)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var history: [CPUStats] = []
    private let monitor: any CPUMonitorProtocol
    private var historyBuffer = RingBuffer<CPUStats>(capacity: 300)

    init(monitor: any CPUMonitorProtocol = CPUMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        do {
            let stats = try await monitor.currentStats()
            historyBuffer.append(stats)
            history = Array(historyBuffer)
            state = .loaded(stats)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetSamplingBaseline() async {
        await monitor.resetBaseline()
    }

    func refreshContinuously(every interval: Duration = .seconds(1)) async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }
}
