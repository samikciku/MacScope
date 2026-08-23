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
    let rendererUtilization: Double?
    let tilerUtilization: Double?
    let allocatedMemoryBytes: UInt64?
    let inUseMemoryBytes: UInt64?
    let coreCount: Int?
    let powerWatts: Double?
    let frequencyMHz: Double?

    init(
        timestamp: Date,
        utilization: MetricAvailability<Double>,
        devices: [GPUDeviceInfo],
        sourceDescription: String?,
        rendererUtilization: Double? = nil,
        tilerUtilization: Double? = nil,
        allocatedMemoryBytes: UInt64? = nil,
        inUseMemoryBytes: UInt64? = nil,
        coreCount: Int? = nil,
        powerWatts: Double? = nil,
        frequencyMHz: Double? = nil
    ) {
        self.timestamp = timestamp
        self.utilization = utilization
        self.devices = devices
        self.sourceDescription = sourceDescription
        self.rendererUtilization = rendererUtilization
        self.tilerUtilization = tilerUtilization
        self.allocatedMemoryBytes = allocatedMemoryBytes
        self.inUseMemoryBytes = inUseMemoryBytes
        self.coreCount = coreCount
        self.powerWatts = powerWatts
        self.frequencyMHz = frequencyMHz
    }
}
