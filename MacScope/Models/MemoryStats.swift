import Foundation

struct MemoryStats: Equatable, Sendable {
    struct Swap: Equatable, Sendable {
        let totalBytes: UInt64
        let usedBytes: UInt64

        var freeBytes: UInt64 { totalBytes - Swift.min(totalBytes, usedBytes) }
    }

    struct Paging: Equatable, Sendable {
        let pageInsBytes: UInt64
        let pageOutsBytes: UInt64
        let pageInsBytesPerSecond: Double?
        let pageOutsBytesPerSecond: Double?
    }

    enum Pressure: String, CaseIterable, Equatable, Sendable {
        case normal
        case warning
        case critical
        case unavailable

        var title: String {
            switch self {
            case .unavailable: "Awaiting Data"
            default: rawValue.capitalized
            }
        }

        var guidance: String {
            switch self {
            case .normal: "macOS is meeting current memory demand. More free RAM is not inherently better because reusable caches improve performance."
            case .warning: "Memory demand is elevated. Review active applications and lower-impact candidates before ending anything."
            case .critical: "Memory demand is severe. Save work, then close high-memory applications you recognize and no longer need."
            case .unavailable: "Waiting for the first public macOS memory-pressure event; MacScope does not guess a normal state."
            }
        }
    }

    let timestamp: Date
    let totalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let freeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64
    let purgeableBytes: UInt64
    let paging: Paging
    let swap: MetricAvailability<Swap>
    let pressure: Pressure
}
