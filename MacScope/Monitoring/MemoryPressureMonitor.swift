import Dispatch
import Foundation

final class MemoryPressureMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var state: MemoryStats.Pressure = .unavailable
    private var source: DispatchSourceMemoryPressure?

    init(startSource: Bool = true) {
        guard startSource else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: DispatchQueue(label: "MacScope.MemoryPressure")
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let event = source?.data else { return }
            self.update(from: event)
        }
        self.source = source
        source.resume()
    }

    deinit {
        source?.cancel()
    }

    func currentState() -> MemoryStats.Pressure {
        lock.withLock { state }
    }

    func update(from event: DispatchSource.MemoryPressureEvent) {
        let next: MemoryStats.Pressure
        if event.contains(.critical) {
            next = .critical
        } else if event.contains(.warning) {
            next = .warning
        } else if event.contains(.normal) {
            next = .normal
        } else {
            return
        }
        lock.withLock { state = next }
    }
}
