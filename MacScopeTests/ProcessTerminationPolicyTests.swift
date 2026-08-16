import Foundation
import Testing
@testable import MacScope

struct ProcessTerminationPolicyTests {
    @Test func deniesSelfCriticalAndRootOwnedProcesses() {
        let policy = ProcessTerminationPolicy()

        #expect(policy.decision(for: snapshot(pid: 42, name: "MacScope", owner: "user"), currentProcessID: 42) != .allowed)
        #expect(policy.decision(for: snapshot(pid: 99, name: "launchd", owner: "user"), currentProcessID: 42) != .allowed)
        #expect(policy.decision(for: snapshot(pid: 99, name: "tool", owner: "root"), currentProcessID: 42) != .allowed)
    }

    @Test func allowsOrdinaryUserProcess() {
        let decision = ProcessTerminationPolicy().decision(
            for: snapshot(pid: 99, name: "TestHelper", owner: "sam"),
            currentProcessID: 42
        )
        #expect(decision == .allowed)
    }

    private func snapshot(pid: Int32, name: String, owner: String) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date()), parentPID: nil, name: name,
            executablePath: nil, residentBytes: 0, virtualBytes: nil, cpuPercent: 0,
            threadCount: 1, owner: owner, architecture: nil, timestamp: Date()
        )
    }
}
