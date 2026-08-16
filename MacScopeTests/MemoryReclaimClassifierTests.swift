import Foundation
import Testing
@testable import MacScope

struct MemoryReclaimClassifierTests {
    @Test func suggestsOnlySustainedIdleCurrentUserProcessesWithKnownIO() {
        let process = snapshot(owner: "sam", bytes: 500_000_000, cpu: 0.2, disk: 5_000)
        let history = (0..<5).map { _ in sample(cpu: 0.3) }

        let result = MemoryReclaimClassifier.assess(
            process,
            history: history,
            terminationDecision: .allowed,
            currentUser: "sam"
        )

        #expect(result.classification == .lowerImpact)
        #expect(result.estimatedResidentBytes == 500_000_000)
    }

    @Test func protectsDeniedProcessesAndDoesNotCallUnknownIOIdle() {
        let process = snapshot(owner: "sam", bytes: 500_000_000, cpu: 0, disk: nil)
        let history = (0..<5).map { _ in sample(cpu: 0) }

        #expect(MemoryReclaimClassifier.assess(
            process, history: history, terminationDecision: .denied(reason: "Protected"), currentUser: "sam"
        ).classification == .protected)
        #expect(MemoryReclaimClassifier.assess(
            process, history: history, terminationDecision: .allowed, currentUser: "sam"
        ).classification == .review)
    }

    @Test func marksRecentWorkAsActive() {
        let process = snapshot(owner: "sam", bytes: 500_000_000, cpu: 8, disk: 0)
        #expect(MemoryReclaimClassifier.assess(
            process, history: [sample(cpu: 8)], terminationDecision: .allowed, currentUser: "sam"
        ).classification == .active)
    }

    @Test func groupSuggestionRequiresEveryTerminableMemberToBeLowerImpact() {
        let candidate = MemoryReclaimAssessment(
            classification: .lowerImpact, reason: "Idle", estimatedResidentBytes: 200_000_000
        )
        let protected = MemoryReclaimAssessment(
            classification: .protected, reason: "Protected", estimatedResidentBytes: 0
        )
        let review = MemoryReclaimAssessment(
            classification: .review, reason: "Review", estimatedResidentBytes: 100_000_000
        )

        let suggested = MemoryReclaimClassifier.assessGroup(
            name: "Browser", assessments: [candidate, protected]
        )
        #expect(suggested.classification == .lowerImpact)
        #expect(suggested.estimatedResidentBytes == 200_000_000)
        #expect(MemoryReclaimClassifier.assessGroup(
            name: "Browser", assessments: [candidate, review]
        ).classification == .review)
    }

    @Test func activeGroupMemberMakesTheApplicationActive() {
        let active = MemoryReclaimAssessment(
            classification: .active, reason: "Working", estimatedResidentBytes: 300_000_000
        )
        #expect(MemoryReclaimClassifier.assessGroup(
            name: "Browser", assessments: [active]
        ).classification == .active)
        #expect(MemoryReclaimClassifier.assessGroup(
            name: "System", assessments: [
                .init(classification: .protected, reason: "Protected", estimatedResidentBytes: 0)
            ]
        ).classification == .protected)
    }

    private func sample(cpu: Double) -> ProcessResourceSample {
        .init(timestamp: Date(), residentBytes: 500_000_000, cpuPercent: cpu)
    }

    private func snapshot(owner: String, bytes: UInt64, cpu: Double, disk: Double?) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: .init(pid: 42, startTime: Date(timeIntervalSince1970: 42)),
            parentPID: 1,
            name: "Candidate",
            executablePath: "/Applications/Candidate.app/Contents/MacOS/Candidate",
            residentBytes: bytes,
            virtualBytes: nil,
            cpuPercent: cpu,
            threadCount: 2,
            owner: owner,
            architecture: "arm64",
            timestamp: Date(),
            diskReadBytesPerSecond: disk,
            diskWriteBytesPerSecond: disk.map { _ in 0 }
        )
    }
}
