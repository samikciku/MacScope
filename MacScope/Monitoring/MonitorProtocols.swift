protocol MemoryMonitorProtocol: Sendable {
    func currentStats() async throws -> MemoryStats
}

protocol CPUMonitorProtocol: Sendable {
    func currentStats() async throws -> CPUStats
}

protocol GPUMonitorProtocol: Sendable {
    func currentStats() async throws -> GPUStats
}

protocol ProcessMonitorProtocol: Sendable {
    func currentProcesses() async throws -> [ProcessSnapshot]
}

protocol SystemMonitorProtocol: Sendable {
    func currentInfo() async throws -> SystemInfo
}

protocol DiskMonitorProtocol: Sendable {
    func currentStats() async throws -> DiskStats
}

protocol NetworkMonitorProtocol: Sendable {
    func currentStats() async throws -> NetworkStats
}

protocol BatteryMonitorProtocol: Sendable {
    func currentStats() async -> MetricAvailability<BatteryStats>
}

protocol ThermalMonitorProtocol: Sendable {
    func currentStats() async -> ThermalStats
}
