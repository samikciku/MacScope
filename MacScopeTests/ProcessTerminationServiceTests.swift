import Foundation
import Testing
@testable import MacScope

struct ProcessTerminationServiceTests {
    @Test func terminatesOnlyAControlledChildProcess() async throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer {
            if child.isRunning { child.terminate() }
        }

        let monitor = ProcessMonitor()
        let snapshots = try await monitor.currentProcesses()
        let snapshot = try #require(snapshots.first { $0.pid == child.processIdentifier })

        try await ProcessTerminationService().send(.terminate, to: snapshot)
        child.waitUntilExit()

        #expect(!child.isRunning)
    }
}
