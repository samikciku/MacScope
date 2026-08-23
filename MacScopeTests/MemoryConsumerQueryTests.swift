import Foundation
import Testing
@testable import MacScope

struct MemoryConsumerQueryTests {
    @Test func sortsLargestFirstAndFiltersByNamePIDOrUser() {
        let small = snapshot(pid: 12, name: "Notes", owner: "sam", bytes: 100)
        let large = snapshot(pid: 45, name: "Firefox", owner: "sam", bytes: 900)
        let medium = snapshot(pid: 30, name: "Worker", owner: "build", bytes: 500)
        let snapshots = [small, large, medium]

        #expect(MemoryConsumerQuery.apply(to: snapshots, searchText: "").map(\.pid) == [45, 30, 12])
        #expect(MemoryConsumerQuery.apply(to: snapshots, searchText: "fire").map(\.pid) == [45])
        #expect(MemoryConsumerQuery.apply(to: snapshots, searchText: "build").map(\.pid) == [30])
        #expect(MemoryConsumerQuery.apply(to: snapshots, searchText: "12").map(\.pid) == [12])
    }

    private func snapshot(pid: Int32, name: String, owner: String, bytes: UInt64) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date(timeIntervalSince1970: TimeInterval(pid))),
            parentPID: 1,
            name: name,
            executablePath: nil,
            residentBytes: bytes,
            virtualBytes: nil,
            cpuPercent: 0,
            threadCount: 1,
            owner: owner,
            architecture: nil,
            timestamp: Date()
        )
    }
}
