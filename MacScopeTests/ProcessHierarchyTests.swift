import Foundation
import Testing
@testable import MacScope

struct ProcessHierarchyTests {
    @Test func buildsParentChildForestAndKeepsOrphans() throws {
        let processes = [
            snapshot(pid: 1, parent: nil, name: "Root"),
            snapshot(pid: 2, parent: 1, name: "Child"),
            snapshot(pid: 3, parent: 2, name: "Grandchild"),
            snapshot(pid: 4, parent: 999, name: "Orphan")
        ]
        let forest = ProcessHierarchy.forest(from: processes)
        let root = try #require(forest.first { $0.process.pid == 1 })

        #expect(root.children.map(\.process.pid) == [2])
        #expect(root.children.first?.children.map(\.process.pid) == [3])
        #expect(forest.contains { $0.process.pid == 4 })
    }

    @Test func searchPreservesAncestorContext() throws {
        let forest = ProcessHierarchy.forest(
            from: [snapshot(pid: 1, parent: nil, name: "Shell"), snapshot(pid: 2, parent: 1, name: "Worker")],
            searchText: "worker"
        )

        let root = try #require(forest.first)
        #expect(root.process.name == "Shell")
        #expect(root.children.first?.process.name == "Worker")
    }

    @Test func breaksParentCyclesWithoutDroppingProcesses() {
        let forest = ProcessHierarchy.forest(from: [
            snapshot(pid: 1, parent: 2, name: "One"),
            snapshot(pid: 2, parent: 1, name: "Two")
        ])

        func count(_ nodes: [ProcessTreeNode]) -> Int {
            nodes.reduce(0) { $0 + 1 + count($1.children) }
        }
        #expect(count(forest) == 2)
    }

    private func snapshot(pid: Int32, parent: Int32?, name: String) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date(timeIntervalSince1970: Double(pid))),
            parentPID: parent,
            name: name,
            executablePath: nil,
            residentBytes: 1,
            virtualBytes: nil,
            cpuPercent: 0,
            threadCount: 1,
            owner: "test",
            architecture: nil,
            timestamp: Date()
        )
    }
}
