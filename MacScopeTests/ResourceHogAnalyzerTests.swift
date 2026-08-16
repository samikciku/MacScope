import Foundation
import Testing
@testable import MacScope

struct ResourceHogAnalyzerTests {
    @Test func aggregatesApplicationProcessesAndRanksThresholdMultiples() {
        let first = snapshot(pid: 10, memory: 700, cpu: 80, disk: 40, power: 3, owner: "sam")
        let second = snapshot(pid: 11, memory: 500, cpu: 50, disk: 30, power: 2, owner: "sam")
        let group = ApplicationProcessGroup(
            id: "app:test", name: "Test App", applicationPath: nil,
            processes: [first, second], residentBytes: 1_200, cpuPercent: 130, threadCount: 2
        )
        let thresholds = ResourceHogThresholds(
            memoryBytes: 1_000, cpuPercent: 100, diskBytesPerSecond: 100,
            networkBytesPerSecond: 100, powerWatts: 10
        )
        let traffic = [
            ProcessNetworkUsage(pid: 10, name: "Test", totalReceivedBytes: 0, totalSentBytes: 0, downloadBytesPerSecond: 60, uploadBytesPerSecond: 20),
            ProcessNetworkUsage(pid: 11, name: "Test", totalReceivedBytes: 0, totalSentBytes: 0, downloadBytesPerSecond: 30, uploadBytesPerSecond: nil)
        ]

        let findings = ResourceHogAnalyzer.findings(groups: [group], processNetworkUsage: traffic, thresholds: thresholds)

        #expect(findings.map(\.category) == [.cpu, .memory, .network])
        #expect(findings.allSatisfy { $0.applicationName == "Test App" && $0.ownerSummary == "sam" })
        #expect(findings.first?.primaryProcessIdentity == first.identity)
    }

    @Test func excludesUnavailableOrBelowThresholdMetrics() {
        let process = snapshot(pid: 10, memory: 100, cpu: 5, disk: nil, power: nil, owner: nil)
        let group = ApplicationProcessGroup(
            id: "process:10", name: "Quiet", applicationPath: nil,
            processes: [process], residentBytes: 100, cpuPercent: 5, threadCount: 1
        )
        let thresholds = ResourceHogThresholds(
            memoryBytes: 1_000, cpuPercent: 100, diskBytesPerSecond: 100,
            networkBytesPerSecond: 100, powerWatts: 10
        )

        #expect(ResourceHogAnalyzer.findings(groups: [group], processNetworkUsage: [], thresholds: thresholds).isEmpty)
    }

    @Test func filtersFindingsByCategoryApplicationAndOwner() {
        let identity = ProcessSnapshot.Identity(pid: 1, startTime: nil)
        let findings = [
            ResourceHogFinding(groupID: "a", applicationName: "Firefox", category: .memory, value: 2, threshold: 1, processCount: 2, ownerSummary: "sam", primaryProcessIdentity: identity),
            ResourceHogFinding(groupID: "b", applicationName: "Builder", category: .cpu, value: 2, threshold: 1, processCount: 1, ownerSummary: "ci-user", primaryProcessIdentity: identity)
        ]

        #expect(ResourceHogQuery.filter(findings, category: .memory, searchText: "").map(\.groupID) == ["a"])
        #expect(ResourceHogQuery.filter(findings, category: nil, searchText: "fire").map(\.groupID) == ["a"])
        #expect(ResourceHogQuery.filter(findings, category: nil, searchText: "CI-USER").map(\.groupID) == ["b"])
        #expect(ResourceHogQuery.filter(findings, category: .network, searchText: "").isEmpty)
    }

    @Test func findingAccessibilitySummaryIncludesNonvisualContext() {
        let finding = ResourceHogFinding(
            groupID: "a", applicationName: "Firefox", category: .memory,
            value: 2, threshold: 1, processCount: 2, ownerSummary: "sam",
            primaryProcessIdentity: .init(pid: 1, startTime: nil)
        )

        #expect(finding.accessibilitySummary(valueDescription: "2 GB") == "Firefox, Memory usage 2 GB, 2.0 times threshold, 2 processes, user sam")
    }

    private func snapshot(
        pid: Int32, memory: UInt64, cpu: Double, disk: Double?, power: Double?, owner: String?
    ) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: pid, startTime: Date(timeIntervalSince1970: Double(pid))),
            parentPID: nil, name: "Test", executablePath: nil, residentBytes: memory,
            virtualBytes: nil, cpuPercent: cpu, threadCount: 1, owner: owner,
            architecture: nil, timestamp: Date(), wakeupsPerSecond: nil,
            diskReadBytesPerSecond: disk, diskWriteBytesPerSecond: nil,
            energyNanojoules: nil, estimatedPowerWatts: power
        )
    }
}
