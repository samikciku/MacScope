@preconcurrency import Metal
import Foundation

struct MetalGPUMonitor: GPUMonitorProtocol {
    func currentStats() async throws -> GPUStats {
        var metalDevices = MTLCopyAllDevices()
        if metalDevices.isEmpty, let defaultDevice = MTLCreateSystemDefaultDevice() {
            metalDevices = [defaultDevice]
        }

        let devices = metalDevices.map {
            GPUDeviceInfo(
                registryID: $0.registryID,
                name: $0.name,
                isLowPower: $0.isLowPower,
                isRemovable: $0.isRemovable,
                isHeadless: $0.isHeadless,
                hasUnifiedMemory: $0.hasUnifiedMemory
            )
        }

        return GPUStats(
            timestamp: Date(),
            utilization: .unsupported(
                reason: "Metal exposes counters for work encoded by this application, not reliable whole-system GPU utilization."
            ),
            devices: devices,
            sourceDescription: "Device metadata: public Metal API"
        )
    }
}
