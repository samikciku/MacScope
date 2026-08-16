import Foundation

struct NetworkInterfaceStats: Identifiable, Equatable, Sendable {
    let name: String
    let receivedBytes: UInt64
    let transmittedBytes: UInt64

    var id: String { name }
}

struct NetworkStats: Equatable, Sendable {
    let timestamp: Date
    let totalReceivedBytes: UInt64
    let totalTransmittedBytes: UInt64
    let downloadBytesPerSecond: Double?
    let uploadBytesPerSecond: Double?
    let interfaces: [NetworkInterfaceStats]
}
