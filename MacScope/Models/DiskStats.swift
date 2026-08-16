import Foundation

struct DiskStats: Equatable, Sendable {
    struct IOActivity: Equatable, Sendable {
        let totalReadBytes: UInt64
        let totalWrittenBytes: UInt64
        let readBytesPerSecond: Double?
        let writeBytesPerSecond: Double?
        let deviceCount: Int
    }

    let timestamp: Date
    let volumeName: String
    let mountPath: String
    let totalBytes: UInt64
    let availableBytes: UInt64
    let isReadOnly: Bool
    let ioActivity: MetricAvailability<IOActivity>

    var usedBytes: UInt64 { totalBytes - Swift.min(totalBytes, availableBytes) }
    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}
