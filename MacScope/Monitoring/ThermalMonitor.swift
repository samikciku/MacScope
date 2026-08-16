import Foundation

struct ThermalMonitor: ThermalMonitorProtocol {
    func currentStats() async -> ThermalStats {
        let info = ProcessInfo.processInfo
        return ThermalStats(
            timestamp: Date(),
            state: map(info.thermalState),
            lowPowerModeEnabled: info.isLowPowerModeEnabled
        )
    }

    private func map(_ state: ProcessInfo.ThermalState) -> ThermalStats.State {
        switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
    }
}
