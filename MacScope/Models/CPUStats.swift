import Foundation

struct CPUStats: Equatable, Sendable {
    let timestamp: Date
    let totalUsage: Double
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let perCoreUsage: [Double]
}
