import Foundation

enum ResourceHogCategory: String, CaseIterable, Identifiable, Sendable {
    case memory
    case cpu
    case disk
    case network
    case power

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .memory: "memorychip"
        case .cpu: "cpu"
        case .disk: "internaldrive"
        case .network: "network"
        case .power: "bolt"
        }
    }
}

struct ResourceHogThresholds: Equatable, Sendable {
    let memoryBytes: UInt64
    let cpuPercent: Double
    let diskBytesPerSecond: Double
    let networkBytesPerSecond: Double
    let powerWatts: Double
}

struct ResourceHogFinding: Identifiable, Equatable, Sendable {
    let groupID: String
    let applicationName: String
    let category: ResourceHogCategory
    let value: Double
    let threshold: Double
    let processCount: Int
    let ownerSummary: String
    let primaryProcessIdentity: ProcessSnapshot.Identity

    var id: String { "\(groupID):\(category.rawValue)" }
    var thresholdMultiple: Double { threshold > 0 ? value / threshold : 0 }

    func accessibilitySummary(valueDescription: String) -> String {
        "\(applicationName), \(category.title) usage \(valueDescription), \(thresholdMultiple.formatted(.number.precision(.fractionLength(1)))) times threshold, \(processCount) \(processCount == 1 ? "process" : "processes"), user \(ownerSummary)"
    }
}

struct ResourceHogMeasurement: Equatable, Sendable {
    let groupID: String
    let applicationName: String
    let category: ResourceHogCategory
    let value: Double
    let threshold: Double
    let processCount: Int
    let ownerSummary: String
    let primaryProcessIdentity: ProcessSnapshot.Identity

    var key: String { "\(groupID):\(category.rawValue)" }
    var finding: ResourceHogFinding {
        ResourceHogFinding(
            groupID: groupID,
            applicationName: applicationName,
            category: category,
            value: value,
            threshold: threshold,
            processCount: processCount,
            ownerSummary: ownerSummary,
            primaryProcessIdentity: primaryProcessIdentity
        )
    }
}
