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
}
