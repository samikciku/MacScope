import Foundation
import Testing
@testable import MacScope

struct ProcessQueryTests {
    @Test func filtersCaseInsensitivelyByNameAndByPID() {
        let processes = [snapshot(pid: 12, name: "Safari", memory: 10, cpu: 2),
                         snapshot(pid: 34, name: "Finder", memory: 20, cpu: 1)]

        #expect(ProcessQuery.apply(to: processes, searchText: "sAf", sortField: .pid, sortOrder: .ascending).map(\.pid) == [12])
        #expect(ProcessQuery.apply(to: processes, searchText: "34", sortField: .pid, sortOrder: .ascending).map(\.pid) == [34])
    }

    @Test func sortsAllRequiredFields() {
        let processes = [snapshot(pid: 2, name: "Beta", memory: 10, cpu: 30),
                         snapshot(pid: 1, name: "Alpha", memory: 20, cpu: 10)]

        #expect(ProcessQuery.apply(to: processes, searchText: "", sortField: .memory, sortOrder: .descending).map(\.pid) == [1, 2])
        #expect(ProcessQuery.apply(to: processes, searchText: "", sortField: .cpu, sortOrder: .descending).map(\.pid) == [2, 1])
        #expect(ProcessQuery.apply(to: processes, searchText: "", sortField: .name, sortOrder: .ascending).map(\.pid) == [1, 2])
        #expect(ProcessQuery.apply(to: processes, searchText: "", sortField: .pid, sortOrder: .ascending).map(\.pid) == [1, 2])
    }

    @Test func filtersBySigningIdentityAndDeveloperTeam() {
        let signed = snapshot(
            pid: 12,
            name: "Helper",
            memory: 10,
            cpu: 2,
            codeSigning: .init(
                validation: .valid,
                signingIdentifier: "com.example.helper",
                teamIdentifier: "TEAM123456"
            )
        )

        #expect(ProcessQuery.apply(to: [signed], searchText: "example.helper", sortField: .pid, sortOrder: .ascending).map(\.pid) == [12])
        #expect(ProcessQuery.apply(to: [signed], searchText: "team123", sortField: .pid, sortOrder: .ascending).map(\.pid) == [12])
    }

    private func snapshot(
        pid: Int32,
        name: String,
        memory: UInt64,
        cpu: Double,
        codeSigning: ProcessCodeSigningInfo? = nil
    ) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date(timeIntervalSince1970: Double(pid))),
            parentPID: nil,
            name: name,
            executablePath: nil,
            residentBytes: memory,
            virtualBytes: nil,
            cpuPercent: cpu,
            threadCount: 1,
            owner: nil,
            architecture: nil,
            codeSigning: codeSigning,
            timestamp: Date()
        )
    }
}
