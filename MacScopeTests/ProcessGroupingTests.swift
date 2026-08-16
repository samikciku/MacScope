import Foundation
import Testing
@testable import MacScope

struct ProcessGroupingTests {
    @Test func groupsHelpersInsideTheSameApplicationBundle() throws {
        let processes = [
            snapshot(pid: 10, name: "Browser", path: "/Applications/Browser.app/Contents/MacOS/Browser", memory: 100, cpu: 20, threads: 2),
            snapshot(pid: 11, name: "Browser Helper", path: "/Applications/Browser.app/Contents/Frameworks/Helper", memory: 200, cpu: 30, threads: 3)
        ]

        let group = try #require(ProcessGrouping.groups(from: processes).first)

        #expect(group.name == "Browser")
        #expect(group.applicationPath == "/Applications/Browser.app")
        #expect(group.processes.count == 2)
        #expect(group.residentBytes == 300)
        #expect(group.cpuPercent == 50)
        #expect(group.threadCount == 5)
    }

    @Test func leavesUnbundledProcessesAsSeparateStableGroups() {
        let processes = [
            snapshot(pid: 10, name: "worker", path: "/usr/bin/worker", memory: 10, cpu: 1, threads: 1),
            snapshot(pid: 11, name: "worker", path: "/usr/bin/worker", memory: 20, cpu: 2, threads: 1)
        ]

        #expect(ProcessGrouping.groups(from: processes).count == 2)
    }

    @Test func filtersChildrenAndSortsByAggregateMemory() {
        let browser = [
            snapshot(pid: 10, name: "Browser", path: "/Applications/Browser.app/Contents/MacOS/Browser", memory: 100, cpu: 1, threads: 1),
            snapshot(pid: 11, name: "Render Helper", path: "/Applications/Browser.app/Contents/MacOS/Helper", memory: 200, cpu: 1, threads: 1)
        ]
        let editor = [
            snapshot(pid: 20, name: "Editor", path: "/Applications/Editor.app/Contents/MacOS/Editor", memory: 400, cpu: 1, threads: 1)
        ]
        let groups = ProcessGrouping.groups(from: browser + editor)

        let sorted = ProcessGrouping.sorted(groups, searchText: "", sortField: .memory, sortOrder: .descending)
        let filtered = ProcessGrouping.sorted(groups, searchText: "render", sortField: .name, sortOrder: .ascending)

        #expect(sorted.map(\.name) == ["Editor", "Browser"])
        #expect(filtered.map(\.name) == ["Browser"])
    }

    @Test(.timeLimit(.minutes(1)))
    func aggregationRemainsCheapForLargeProcessLists() {
        var processes: [ProcessSnapshot] = []
        processes.reserveCapacity(500)
        for index in 0..<500 {
            let process = snapshot(
                pid: Int32(index + 100),
                name: "Helper \(index)",
                path: "/Applications/App\(index % 50).app/Contents/MacOS/Helper\(index)",
                memory: UInt64(index + 1) * 1_024,
                cpu: Double(index % 20),
                threads: 2
            )
            processes.append(process)
        }
        let clock = ContinuousClock()
        let duration = clock.measure {
            for _ in 0..<100 {
                _ = ProcessGrouping.groups(from: processes)
            }
        }

        #expect(duration < .seconds(2))
    }

    private func snapshot(
        pid: Int32,
        name: String,
        path: String,
        memory: UInt64,
        cpu: Double,
        threads: Int
    ) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date(timeIntervalSince1970: Double(pid))),
            parentPID: nil,
            name: name,
            executablePath: path,
            residentBytes: memory,
            virtualBytes: nil,
            cpuPercent: cpu,
            threadCount: threads,
            owner: "test",
            architecture: nil,
            timestamp: Date()
        )
    }
}
