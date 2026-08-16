import Foundation

@MainActor
final class ThermalViewModel: ObservableObject {
    @Published private(set) var stats: ThermalStats?
    @Published private(set) var history: [ThermalStats] = []
    private let monitor: any ThermalMonitorProtocol
    private var historyBuffer = RingBuffer<ThermalStats>(capacity: 300)

    init(monitor: any ThermalMonitorProtocol = ThermalMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        let sample = await monitor.currentStats()
        historyBuffer.append(sample)
        history = Array(historyBuffer)
        stats = sample
    }
}
