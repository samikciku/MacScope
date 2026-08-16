import Foundation
import Testing
@testable import MacScope

struct SystemHealthAnalyzerTests {
    @Test func criticalSignalsTakePriority() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .critical, cpuUsage: 1, diskUsedFraction: 0.99,
            thermalState: .nominal, topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(result.level == .critical)
        #expect(result.destination == .performance)
        #expect(result.title.contains("Memory"))
    }

    @Test func elevatedCPUIdentifiesVisibleContributor() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, cpuUsage: 0.95, diskUsedFraction: 0.5,
            thermalState: .nominal, topMemoryProcess: nil, topCPUProcess: process(name: "Compiler")
        )
        #expect(result.level == .elevated)
        #expect(result.evidence.contains("Compiler"))
        #expect(result.destination == .applications)
    }

    @Test func normalSignalsRecommendNoAction() {
        let result = SystemHealthAnalyzer.assess(
            memoryPressure: .normal, cpuUsage: 0.2, diskUsedFraction: 0.4,
            thermalState: .nominal, topMemoryProcess: nil, topCPUProcess: nil
        )
        #expect(result.level == .healthy)
        #expect(result.recommendation.contains("No action"))
    }

    private func process(name: String) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: 7, startTime: Date()), parentPID: 1, name: name,
            executablePath: nil, residentBytes: 1, virtualBytes: nil, cpuPercent: 100,
            threadCount: 1, owner: "test", architecture: nil, timestamp: Date()
        )
    }
}
