protocol MemoryMonitorProtocol: Sendable {
    func currentStats() async throws -> MemoryStats
    func resetBaseline() async
}

extension MemoryMonitorProtocol { func resetBaseline() async {} }

protocol CPUMonitorProtocol: Sendable {
    func currentStats() async throws -> CPUStats
    func resetBaseline() async
}

extension CPUMonitorProtocol { func resetBaseline() async {} }

protocol GPUMonitorProtocol: Sendable {
    func currentStats() async throws -> GPUStats
}

protocol ProcessMonitorProtocol: Sendable {
    func currentProcesses() async throws -> [ProcessSnapshot]
    func resetBaseline() async
}

extension ProcessMonitorProtocol { func resetBaseline() async {} }

protocol SystemMonitorProtocol: Sendable {
    func currentInfo() async throws -> SystemInfo
}

protocol DiskMonitorProtocol: Sendable {
    func currentStats() async throws -> DiskStats
    func resetBaseline() async
}

extension DiskMonitorProtocol { func resetBaseline() async {} }

protocol NetworkMonitorProtocol: Sendable {
    func currentStats() async throws -> NetworkStats
    func resetBaseline() async
}

extension NetworkMonitorProtocol { func resetBaseline() async {} }

protocol BatteryMonitorProtocol: Sendable {
    func currentStats() async -> MetricAvailability<BatteryStats>
}

protocol ThermalMonitorProtocol: Sendable {
    func currentStats() async -> ThermalStats
}
