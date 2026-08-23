import Foundation

enum MemoryReclaimClassification: String, CaseIterable, Identifiable, Sendable {
    case lowerImpact = "Lower-impact candidate"
    case review = "Review manually"
    case active = "Active"
    case protected = "Protected"

    var id: Self { self }
    var systemImage: String {
        switch self {
        case .lowerImpact: "leaf"
        case .review: "questionmark.circle"
        case .active: "waveform.path.ecg"
        case .protected: "lock.shield"
        }
    }
}

struct MemoryReclaimAssessment: Equatable, Sendable {
    let classification: MemoryReclaimClassification
    let reason: String
    let estimatedResidentBytes: UInt64
}

enum MemoryReclaimClassifier {
    static let highMemoryRecommendationThreshold: UInt64 = 500_000_000

    static func recommendationReason(
        for assessment: MemoryReclaimAssessment,
        residentBytes: UInt64,
        isApplication: Bool
    ) -> String? {
        guard isApplication, assessment.classification != .protected else { return nil }
        if assessment.classification == .lowerImpact {
            return "Low recent activity makes this a lower-impact app to quit."
        }
        guard residentBytes >= highMemoryRecommendationThreshold else { return nil }
        if assessment.classification == .active {
            return "High memory use; this app appears active, so review it before quitting."
        }
        return "High memory use makes this app worth reviewing before quitting."
    }

    static func assess(
        _ process: ProcessSnapshot,
        history: [ProcessResourceSample],
        terminationDecision: ProcessTerminationDecision,
        currentUser: String = NSUserName()
    ) -> MemoryReclaimAssessment {
        if case .denied(let reason) = terminationDecision {
            return .init(classification: .protected, reason: reason, estimatedResidentBytes: 0)
        }

        let recent = Array(history.suffix(5))
        let diskRate: Double? = {
            guard process.diskReadBytesPerSecond != nil || process.diskWriteBytesPerSecond != nil else { return nil }
            return (process.diskReadBytesPerSecond ?? 0) + (process.diskWriteBytesPerSecond ?? 0)
        }()
        if process.cpuPercent >= 5
            || recent.contains(where: { $0.cpuPercent >= 5 })
            || (diskRate ?? 0) >= 1_000_000 {
            return .init(
                classification: .active,
                reason: "Recent CPU or disk activity indicates that this process is doing work.",
                estimatedResidentBytes: process.residentBytes
            )
        }
        guard process.owner == currentUser else {
            return .init(
                classification: .review,
                reason: "The process is not owned by the current user.",
                estimatedResidentBytes: process.residentBytes
            )
        }
        guard recent.count >= 3 else {
            return .init(
                classification: .review,
                reason: "Collecting more activity history before suggesting a graceful quit.",
                estimatedResidentBytes: process.residentBytes
            )
        }
        guard let diskRate else {
            return .init(
                classification: .review,
                reason: "Disk activity is unavailable, so low impact cannot be established.",
                estimatedResidentBytes: process.residentBytes
            )
        }
        let averageCPU = recent.reduce(0) { $0 + $1.cpuPercent } / Double(recent.count)
        if process.residentBytes >= 100_000_000, averageCPU < 1, diskRate < 100_000 {
            return .init(
                classification: .lowerImpact,
                reason: "User-owned, at least 100 MB resident, and recently below conservative CPU and disk activity limits.",
                estimatedResidentBytes: process.residentBytes
            )
        }
        return .init(
            classification: .review,
            reason: "The evidence is insufficient for a lower-impact suggestion.",
            estimatedResidentBytes: process.residentBytes
        )
    }

    static func assessGroup(
        name: String,
        assessments: [MemoryReclaimAssessment]
    ) -> MemoryReclaimAssessment {
        let terminable = assessments.filter { $0.classification != .protected }
        guard !terminable.isEmpty else {
            return .init(
                classification: .protected,
                reason: "No process in \(name) is eligible for termination.",
                estimatedResidentBytes: 0
            )
        }

        let estimatedBytes = clampedSum(terminable.map(\.estimatedResidentBytes))
        if terminable.contains(where: { $0.classification == .active }) {
            return .init(
                classification: .active,
                reason: "At least one process in this application is currently active.",
                estimatedResidentBytes: estimatedBytes
            )
        }
        if terminable.allSatisfy({ $0.classification == .lowerImpact }) {
            let protectedCount = assessments.count - terminable.count
            return .init(
                classification: .lowerImpact,
                reason: "Every terminable process is a lower-impact candidate.\(protectedCount > 0 ? " \(protectedCount) protected process(es) will be skipped." : "")",
                estimatedResidentBytes: estimatedBytes
            )
        }
        return .init(
            classification: .review,
            reason: "At least one process in this application needs manual review.",
            estimatedResidentBytes: estimatedBytes
        )
    }

    private static func clampedSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { result, value in
            let addition = result.addingReportingOverflow(value)
            return addition.overflow ? .max : addition.partialValue
        }
    }
}
