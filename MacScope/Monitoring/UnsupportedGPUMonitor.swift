import Foundation

struct UnsupportedGPUMonitor: GPUMonitorProtocol {
    func currentStats() async throws -> GPUStats {
        GPUStats(
            timestamp: Date(),
            utilization: .unsupported(
                reason: "A reliable public GPU utilization source has not been configured."
            ),
            devices: [],
            sourceDescription: nil
        )
    }
}
