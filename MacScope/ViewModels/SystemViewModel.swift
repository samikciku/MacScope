import Foundation

@MainActor
final class SystemViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(SystemInfo)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    private let monitor: any SystemMonitorProtocol

    init(monitor: any SystemMonitorProtocol = SystemMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        do {
            state = .loaded(try await monitor.currentInfo())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
