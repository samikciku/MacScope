import Foundation

@MainActor
final class MonitoringCoordinator {
    private let memoryViewModel: MemoryViewModel
    private let cpuViewModel: CPUViewModel
    private let processesViewModel: ProcessesViewModel
    private let gpuViewModel: GPUViewModel
    private let systemViewModel: SystemViewModel
    private let diskViewModel: DiskViewModel
    private let networkViewModel: NetworkViewModel
    private let batteryViewModel: BatteryViewModel
    private let thermalViewModel: ThermalViewModel
    private let settings: MonitoringSettings
    private let alertCenter: AlertCenter
    private let alertEvaluator: ResourceAlertEvaluator

    private var memoryTask: Task<Void, Never>?
    private var cpuTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var gpuTask: Task<Void, Never>?
    private var systemTask: Task<Void, Never>?
    private var diskTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var thermalTask: Task<Void, Never>?

    init(
        memoryViewModel: MemoryViewModel,
        cpuViewModel: CPUViewModel,
        processesViewModel: ProcessesViewModel,
        gpuViewModel: GPUViewModel,
        systemViewModel: SystemViewModel,
        diskViewModel: DiskViewModel,
        networkViewModel: NetworkViewModel,
        batteryViewModel: BatteryViewModel,
        thermalViewModel: ThermalViewModel,
        settings: MonitoringSettings,
        alertCenter: AlertCenter,
        alertEvaluator: ResourceAlertEvaluator
    ) {
        self.memoryViewModel = memoryViewModel
        self.cpuViewModel = cpuViewModel
        self.processesViewModel = processesViewModel
        self.gpuViewModel = gpuViewModel
        self.systemViewModel = systemViewModel
        self.diskViewModel = diskViewModel
        self.networkViewModel = networkViewModel
        self.batteryViewModel = batteryViewModel
        self.thermalViewModel = thermalViewModel
        self.settings = settings
        self.alertCenter = alertCenter
        self.alertEvaluator = alertEvaluator
    }

    func start() {
        guard memoryTask == nil else { return }

        memoryTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await memoryViewModel.refresh()
                if case .loaded(let stats) = memoryViewModel.state {
                    alertCenter.observeMemoryPressure(stats.pressure, at: stats.timestamp)
                }
                await evaluateSwapAlert()
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        cpuTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await cpuViewModel.refresh()
                await evaluateCPUAlert()
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        processTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await processesViewModel.refresh()
                guard await sleep(for: settings.processRefreshDuration) else { return }
            }
        }
        gpuTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await gpuViewModel.refresh()
        }
        systemTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await systemViewModel.refresh()
        }
        diskTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await diskViewModel.refresh()
                await evaluateDiskAlert()
                let seconds = Swift.max(5, settings.refreshInterval.rawValue)
                guard await sleep(for: .milliseconds(Int(seconds * 1_000))) else { return }
            }
        }
        networkTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await networkViewModel.refresh()
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        batteryTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await batteryViewModel.refresh()
                await evaluateBatteryAlert()
                guard await sleep(for: .seconds(30)) else { return }
            }
        }
        thermalTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await thermalViewModel.refresh()
                if let stats = thermalViewModel.stats { alertCenter.observeThermalState(stats) }
                await evaluateThermalAlert()
                guard await sleep(for: .seconds(5)) else { return }
            }
        }
    }

    private func sleep(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return true
        } catch {
            return false
        }
    }

    private func evaluateCPUAlert() async {
        guard case .loaded(let stats) = cpuViewModel.state else { return }
        if let event = await alertEvaluator.evaluate(
            kind: .cpu,
            value: stats.totalUsage,
            at: stats.timestamp,
            rule: settings.cpuAlertRule,
            message: { value, threshold in
                "CPU remained at \(value.formatted(.percent.precision(.fractionLength(1)))) or higher than the \(threshold.formatted(.percent.precision(.fractionLength(0)))) threshold."
            }
        ) {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }

    private func evaluateSwapAlert() async {
        guard case .loaded(let stats) = memoryViewModel.state,
              case .available(let swap) = stats.swap else { return }
        if let event = await alertEvaluator.evaluate(
            kind: .swap,
            value: Double(swap.usedBytes),
            at: stats.timestamp,
            rule: settings.swapAlertRule,
            message: { value, threshold in
                "Swap usage reached \(ByteFormatter.string(fromByteCount: UInt64(value))) above the configured \(ByteFormatter.string(fromByteCount: UInt64(threshold))) threshold."
            }
        ) {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }

    private func evaluateThermalAlert() async {
        guard let stats = thermalViewModel.stats else { return }
        if let event = await alertEvaluator.evaluate(
            kind: .thermal,
            value: Double(stats.state.rawValue),
            at: stats.timestamp,
            rule: settings.thermalAlertRule,
            message: { value, _ in
                let state = ThermalStats.State(rawValue: Int(value))?.title ?? "Elevated"
                return "System thermal pressure remained \(state.lowercased()) or higher for the configured duration."
            }
        ) {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }

    private func evaluateDiskAlert() async {
        guard case .loaded(let stats) = diskViewModel.state else { return }
        if let event = await alertEvaluator.evaluate(
            kind: .diskCapacity,
            value: stats.usedFraction,
            at: stats.timestamp,
            rule: settings.diskAlertRule,
            message: { value, threshold in
                "Startup volume usage remained at \(value.formatted(.percent.precision(.fractionLength(1)))) above the configured \(threshold.formatted(.percent.precision(.fractionLength(0)))) threshold."
            }
        ) {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }

    private func evaluateBatteryAlert() async {
        guard case .loaded(let stats) = batteryViewModel.state else { return }
        if let event = await alertEvaluator.evaluate(
            kind: .battery,
            value: stats.chargeFraction,
            at: stats.timestamp,
            rule: settings.batteryAlertRule,
            message: { value, threshold in
                "Battery charge remained at \(value.formatted(.percent.precision(.fractionLength(0)))) below the configured \(threshold.formatted(.percent.precision(.fractionLength(0)))) threshold."
            }
        ) {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }
}
