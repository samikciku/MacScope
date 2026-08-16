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

        var title: String { rawValue.capitalized }
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
