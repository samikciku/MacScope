import Foundation
import Testing
@testable import MacScope

struct SystemHealthAnalyzerTests {
    @Test func criticalSignalsTakePriority() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .critical, memoryTimestamp: Date(), cpuHistory: cpuHistory(value: 1),
            diskUsedFraction: 0.99, diskTimestamp: Date(), thermalState: .nominal, thermalTimestamp: Date(),
            topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(result.level == .critical)
        #expect(result.destination == .performance)
        #expect(result.title.contains("Memory"))
    }

    @Test func elevatedCPUIdentifiesVisibleContributor() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, memoryTimestamp: Date(), cpuHistory: cpuHistory(value: 0.95),
            diskUsedFraction: 0.5, diskTimestamp: Date(), thermalState: .nominal, thermalTimestamp: Date(),
            topMemoryProcess: nil, topCPUProcess: process(name: "Compiler")
        )
        #expect(result.level == .elevated)
        #expect(result.evidence.contains("Compiler"))
        #expect(result.destination == .applications)
    }

    @Test func normalSignalsRecommendNoAction() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, memoryTimestamp: Date(), cpuHistory: cpuHistory(value: 0.2),
            diskUsedFraction: 0.4, diskTimestamp: Date(), thermalState: .nominal, thermalTimestamp: Date(),
            topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(result.level == .healthy)
        #expect(result.recommendation.contains("No action"))
    }

    @Test func missingEvidenceNeverClaimsHealthy() {
        let collecting = SystemHealthAnalyzer.assess(
            memoryPressure: nil, memoryTimestamp: nil, cpuHistory: [], diskUsedFraction: nil,
            diskTimestamp: nil, thermalState: nil, thermalTimestamp: nil,
            topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(collecting.level == .collecting)

        let partial = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, memoryTimestamp: Date(), cpuHistory: [], diskUsedFraction: nil,
            diskTimestamp: nil, thermalState: nil, thermalTimestamp: nil,
            topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(partial.level == .partial)
    }

    @Test func oldEvidenceIsStaleAndShortSpikeIsNotSustained() {
        let now = Date()
        let stale = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, memoryTimestamp: now.addingTimeInterval(-30),
            cpuHistory: cpuHistory(value: 1, now: now, duration: 2), diskUsedFraction: 0.5,
            diskTimestamp: now, thermalState: .nominal, thermalTimestamp: now,
            topMemoryProcess: nil, topCPUProcess: nil, now: now
        )
        #expect(stale.level == .stale)
        #expect(!SystemHealthAnalyzer.sustainedHighCPU(cpuHistory(value: 1, now: now, duration: 2), now: now))
    }

    private func cpuHistory(value: Double, now: Date = Date(), duration: Int = 16) -> [CPUStats] {
        (0...duration).map { offset in
            CPUStats(
                timestamp: now.addingTimeInterval(Double(offset - duration)), totalUsage: value,
                userUsage: value, systemUsage: 0, idleUsage: 1 - value, perCoreUsage: [value]
            )
        }
    }

    private func process(name: String) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: 7, startTime: Date()), parentPID: 1, name: name,
            executablePath: nil, residentBytes: 1, virtualBytes: nil, cpuPercent: 100,
            threadCount: 1, owner: "test", architecture: nil, timestamp: Date()
        )
    }
}
