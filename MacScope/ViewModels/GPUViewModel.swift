import Foundation

enum GPUDataSource: String, CaseIterable, Identifiable, Sendable {
    case metal
    case experimentalIORegistry

    var id: Self { self }
    var title: String {
        switch self {
        case .metal: "Metal metadata"
        case .experimentalIORegistry: "Experimental live metrics"
        }
    }
}

@MainActor
final class GPUViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(GPUStats)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var utilizationHistory: [(timestamp: Date, utilization: Double)] = []
    @Published var source: GPUDataSource {
        didSet {
            defaults.set(source.rawValue, forKey: Self.sourceKey)
            historyBuffer = RingBuffer(capacity: 300)
            utilizationHistory = []
            state = .loading
        }
    }
    private static let sourceKey = "gpu.dataSource"
    private let defaults: UserDefaults
    private let injectedMonitor: (any GPUMonitorProtocol)?
    private var historyBuffer = RingBuffer<GPUUtilizationSample>(capacity: 300)

    init(monitor: (any GPUMonitorProtocol)? = nil, defaults: UserDefaults = .standard) {
        self.injectedMonitor = monitor
        self.defaults = defaults
        self.source = defaults.string(forKey: Self.sourceKey)
            .flatMap(GPUDataSource.init(rawValue:)) ?? .experimentalIORegistry
    }

    func refresh() async {
        do {
            let monitor: any GPUMonitorProtocol = injectedMonitor ?? {
                switch source {
                case .metal: MetalGPUMonitor()
                case .experimentalIORegistry: ExperimentalIORegistryGPUMonitor()
                }
            }()
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
