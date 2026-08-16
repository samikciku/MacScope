import Testing
@testable import MacScope

struct MonitoringStabilityTests {
    @Test(.timeLimit(.minutes(1)))
    func repeatedlySamplesAllRecurringCollectors() async throws {
        let memoryMonitor = MemoryMonitor()
        let cpuMonitor = CPUMonitor()
        let processMonitor = ProcessMonitor()
        let diskMonitor = DiskMonitor()
        let networkMonitor = NetworkMonitor()
        let batteryMonitor = BatteryMonitor()
        let thermalMonitor = ThermalMonitor()

        for index in 0..<300 {
            async let memory = memoryMonitor.currentStats()
            async let cpu = cpuMonitor.currentStats()
            async let processes = processMonitor.currentProcesses()
            let (memoryStats, cpuStats, processStats) = try await (memory, cpu, processes)

            #expect(memoryStats.usedBytes <= memoryStats.totalBytes)
            #expect((0...1).contains(cpuStats.totalUsage))
            #expect(!processStats.isEmpty)
            if index.isMultiple(of: 50) {
                let diskStats = try await diskMonitor.currentStats()
                #expect(diskStats.usedBytes <= diskStats.totalBytes)
            }
            if index.isMultiple(of: 10) {
                let networkStats = try await networkMonitor.currentStats()
                #expect(networkStats.interfaces.allSatisfy { !$0.name.isEmpty })
            }
            if index.isMultiple(of: 100) {
                switch await batteryMonitor.currentStats() {
                case .available(let stats): #expect((0...1).contains(stats.chargeFraction))
                case .unavailable(let reason), .unsupported(let reason): #expect(!reason.isEmpty)
                }
            }
            if index.isMultiple(of: 50) {
                let thermalStats = await thermalMonitor.currentStats()
                #expect((0...3).contains(thermalStats.state.rawValue))
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
