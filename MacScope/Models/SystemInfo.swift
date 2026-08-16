import Foundation

struct SystemInfo: Equatable, Sendable {
    let modelName: String
    let processorName: String
    let physicalMemoryBytes: UInt64
    let operatingSystemVersion: String
    let architecture: String
    let uptimeSeconds: TimeInterval
    let logicalCoreCount: Int
}
