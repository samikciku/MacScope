import Foundation

@MainActor
final class GPUViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(GPUStats)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var utilizationHistory: [(timestamp: Date, utilization: Double)] = []
    private let monitor: any GPUMonitorProtocol
    private var historyBuffer = RingBuffer<GPUUtilizationSample>(capacity: 300)

    init(monitor: any GPUMonitorProtocol = MetalGPUMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        do {
            let stats = try await monitor.currentStats()
            if case .available(let utilization) = stats.utilization {
                historyBuffer.append(.init(timestamp: stats.timestamp, utilization: utilization))
                utilizationHistory = Array(historyBuffer).map { ($0.timestamp, $0.utilization) }
            }
            state = .loaded(stats)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct GPUUtilizationSample: Sendable {
    let timestamp: Date
    let utilization: Double
}
