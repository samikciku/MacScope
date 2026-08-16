import Foundation

@MainActor
final class BatteryViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(BatteryStats)
        case unavailable(String)
        case unsupported(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var history: [BatteryStats] = []
    private let monitor: any BatteryMonitorProtocol
    private var historyBuffer = RingBuffer<BatteryStats>(capacity: 300)

    init(monitor: any BatteryMonitorProtocol = BatteryMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        switch await monitor.currentStats() {
        case .available(let stats):
            historyBuffer.append(stats)
            history = Array(historyBuffer)
            state = .loaded(stats)
        case .unavailable(let reason): state = .unavailable(reason)
        case .unsupported(let reason): state = .unsupported(reason)
        }
    }
}
