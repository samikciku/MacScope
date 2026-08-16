import Foundation

struct ProcessResourceSample: Equatable, Sendable {
    let timestamp: Date
    let residentBytes: UInt64
    let cpuPercent: Double
}
