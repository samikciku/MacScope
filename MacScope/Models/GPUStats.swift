import Foundation

struct GPUDeviceInfo: Equatable, Sendable, Identifiable {
    let registryID: UInt64
    let name: String
    let isLowPower: Bool
    let isRemovable: Bool
    let isHeadless: Bool
    let hasUnifiedMemory: Bool

    var id: UInt64 { registryID }
}

struct GPUStats: Equatable, Sendable {
    let timestamp: Date
    let utilization: MetricAvailability<Double>
    let devices: [GPUDeviceInfo]
    let sourceDescription: String?
}
