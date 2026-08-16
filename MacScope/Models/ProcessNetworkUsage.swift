import Foundation

struct ProcessNetworkUsage: Identifiable, Equatable, Sendable {
    let pid: Int32
    let name: String
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64
    let downloadBytesPerSecond: Double?
    let uploadBytesPerSecond: Double?

    var id: Int32 { pid }
    var currentBytesPerSecond: Double? {
        guard downloadBytesPerSecond != nil || uploadBytesPerSecond != nil else { return nil }
        return (downloadBytesPerSecond ?? 0) + (uploadBytesPerSecond ?? 0)
    }
}
