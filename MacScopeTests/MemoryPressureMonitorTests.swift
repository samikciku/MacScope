import Dispatch
import Foundation
import Testing
@testable import MacScope

struct MemoryPressureMonitorTests {
    @Test func mapsPublicDispatchPressureEventsBySeverity() {
        let monitor = MemoryPressureMonitor(startSource: false)
        #expect(monitor.currentState() == .unavailable)

        monitor.update(from: .normal)
        #expect(monitor.currentState() == .normal)
        monitor.update(from: [.normal, .warning])
        #expect(monitor.currentState() == .warning)
        monitor.update(from: [.warning, .critical])
        #expect(monitor.currentState() == .critical)
    }

    @Test @MainActor func timelineRecordsOnlyKnownPressureTransitions() {
        let center = AlertCenter()
        let start = Date(timeIntervalSince1970: 100)
        center.observeMemoryPressure(.unavailable, at: start)
        center.observeMemoryPressure(.normal, at: start)
        center.observeMemoryPressure(.normal, at: start.addingTimeInterval(1))
        center.observeMemoryPressure(.warning, at: start.addingTimeInterval(2))
        center.observeMemoryPressure(.critical, at: start.addingTimeInterval(3))
        center.observeMemoryPressure(.normal, at: start.addingTimeInterval(4))

        #expect(center.systemEvents.count == 3)
        #expect(center.systemEvents[0].severity == .warning)
        #expect(center.systemEvents[1].severity == .critical)
        #expect(center.systemEvents[2].severity == .information)
    }
}
