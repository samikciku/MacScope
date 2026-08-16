import Foundation

@MainActor
final class NetworkViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(NetworkStats)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var history: [NetworkStats] = []
    @Published private(set) var processTraffic: MetricAvailability<[ProcessNetworkUsage]> = .unavailable(reason: "Collecting per-process traffic…")
    private let monitor: any NetworkMonitorProtocol
    private let processNetworkMonitor: ProcessNetworkMonitor
    private var historyBuffer = RingBuffer<NetworkStats>(capacity: 300)

    init(
        monitor: any NetworkMonitorProtocol = NetworkMonitor(),
        processNetworkMonitor: ProcessNetworkMonitor = ProcessNetworkMonitor()
    ) {
        self.monitor = monitor
        self.processNetworkMonitor = processNetworkMonitor
    }

    func refresh() async {
        do {
            let stats = try await monitor.currentStats()
            historyBuffer.append(stats)
            history = Array(historyBuffer)
            state = .loaded(stats)
            processTraffic = await processNetworkMonitor.currentUsage()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetSamplingBaseline() async {
        await monitor.resetBaseline()
        await processNetworkMonitor.resetBaseline()
    }
}
