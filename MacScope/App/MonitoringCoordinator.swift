import AppKit
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
    private let resourceHogAlertEvaluator: ResourceHogAlertEvaluator
    private let diagnostics: MonitoringDiagnostics

    private var memoryTask: Task<Void, Never>?
    private var cpuTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var gpuTask: Task<Void, Never>?
    private var systemTask: Task<Void, Never>?
    private var diskTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var thermalTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var samplingGeneration: UInt64 = 0
    private let clock = ContinuousClock()

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
        alertEvaluator: ResourceAlertEvaluator,
        resourceHogAlertEvaluator: ResourceHogAlertEvaluator,
        diagnostics: MonitoringDiagnostics
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
        self.resourceHogAlertEvaluator = resourceHogAlertEvaluator
        self.diagnostics = diagnostics
    }

    func start() {
        installWorkspaceObservers()
        startSampling()
    }

    private func startSampling() {
        guard memoryTask == nil else { return }
        samplingGeneration &+= 1
        let generation = samplingGeneration
        diagnostics.resumedAfterWake()

        Task { [weak self] in
            guard let self else { return }
            await resetRateBaselines()
            guard generation == samplingGeneration else { return }
            launchSamplingTasks(generation: generation)
        }
    }

    private func launchSamplingTasks(generation: UInt64) {
        guard generation == samplingGeneration, memoryTask == nil else { return }

        memoryTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.memory, generation: generation) { await memoryViewModel.refresh(); return memorySucceeded }
                guard isCurrent(generation) else { return }
                if case .loaded(let stats) = memoryViewModel.state {
                    alertCenter.observeMemoryPressure(stats.pressure, at: stats.timestamp)
                }
                await evaluateSwapAlert()
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        cpuTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.cpu, generation: generation) { await cpuViewModel.refresh(); return cpuSucceeded }
                guard isCurrent(generation) else { return }
                await evaluateCPUAlert()
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        if DistributionChannel.allowsProcessInspection {
            processTask = Task { [weak self] in
                while let self, isCurrent(generation) {
                    await measure(.processes, generation: generation) { await processesViewModel.refresh(); return processesSucceeded }
                    guard isCurrent(generation) else { return }
                    await evaluateResourceHogAlerts()
                    guard await sleep(for: settings.processRefreshDuration) else { return }
                }
            }
        }
        gpuTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.gpu, generation: generation) { await gpuViewModel.refresh(); return gpuSucceeded }
                let seconds = Swift.max(2, settings.refreshInterval.rawValue)
                guard await sleep(for: .milliseconds(Int(seconds * 1_000))) else { return }
            }
        }
        systemTask = Task { [weak self] in
            guard let self, isCurrent(generation) else { return }
            await measure(.system, generation: generation) { await systemViewModel.refresh(); return systemSucceeded }
        }
        diskTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.disk, generation: generation) { await diskViewModel.refresh(); return diskSucceeded }
                guard isCurrent(generation) else { return }
                await evaluateDiskAlert()
                let seconds = Swift.max(5, settings.refreshInterval.rawValue)
                guard await sleep(for: .milliseconds(Int(seconds * 1_000))) else { return }
            }
        }
        networkTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.network, generation: generation) { await networkViewModel.refresh(); return networkSucceeded }
                guard await sleep(for: settings.refreshInterval.duration) else { return }
            }
        }
        batteryTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.battery, generation: generation) { await batteryViewModel.refresh(); return batterySucceeded }
                guard isCurrent(generation) else { return }
                if case .loaded(let stats) = batteryViewModel.state {
                    alertCenter.observeBatteryState(stats)
                }
                await evaluateBatteryAlert()
                guard await sleep(for: .seconds(30)) else { return }
            }
        }
        thermalTask = Task { [weak self] in
            while let self, isCurrent(generation) {
                await measure(.thermal, generation: generation) { await thermalViewModel.refresh(); return thermalViewModel.stats != nil }
                guard isCurrent(generation) else { return }
                if let stats = thermalViewModel.stats { alertCenter.observeThermalState(stats) }
                await evaluateThermalAlert()
                guard await sleep(for: .seconds(5)) else { return }
            }
        }
    }

    private func installWorkspaceObservers() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pauseForSleep() }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.startSampling() }
        })
    }

    private func pauseForSleep() {
        samplingGeneration &+= 1
        diagnostics.pausedForSleep()
        let tasks = [memoryTask, cpuTask, processTask, gpuTask, systemTask, diskTask, networkTask, batteryTask, thermalTask]
        tasks.forEach { $0?.cancel() }
        memoryTask = nil
        cpuTask = nil
        processTask = nil
        gpuTask = nil
        systemTask = nil
        diskTask = nil
        networkTask = nil
        batteryTask = nil
        thermalTask = nil
    }

    private func measure(
        _ collector: MonitorCollector,
        generation: UInt64,
        operation: () async -> Bool
    ) async {
        let started = clock.now
        let succeeded = await operation()
        guard isCurrent(generation) else { return }
        let elapsed = started.duration(to: clock.now)
        let components = elapsed.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        diagnostics.record(collector, duration: Swift.max(0, seconds), succeeded: succeeded)
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        !Task.isCancelled && generation == samplingGeneration
    }

    private func resetRateBaselines() async {
        async let memory: Void = memoryViewModel.resetSamplingBaseline()
        async let cpu: Void = cpuViewModel.resetSamplingBaseline()
        async let disk: Void = diskViewModel.resetSamplingBaseline()
        async let network: Void = networkViewModel.resetSamplingBaseline()
        if DistributionChannel.allowsProcessInspection {
            await processesViewModel.resetSamplingBaseline()
        }
        _ = await (memory, cpu, disk, network)
    }

    private var memorySucceeded: Bool { if case .loaded = memoryViewModel.state { true } else { false } }
    private var cpuSucceeded: Bool { if case .loaded = cpuViewModel.state { true } else { false } }
    private var processesSucceeded: Bool { if case .loaded = processesViewModel.state { true } else { false } }
    private var gpuSucceeded: Bool { if case .loaded = gpuViewModel.state { true } else { false } }
    private var systemSucceeded: Bool { if case .loaded = systemViewModel.state { true } else { false } }
    private var diskSucceeded: Bool { if case .loaded = diskViewModel.state { true } else { false } }
    private var networkSucceeded: Bool { if case .loaded = networkViewModel.state { true } else { false } }
    private var batterySucceeded: Bool {
        switch batteryViewModel.state {
        case .loaded, .unsupported: true
        case .loading, .unavailable: false
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

    private func evaluateResourceHogAlerts() async {
        guard case .loaded = processesViewModel.state else { return }
        let traffic: [ProcessNetworkUsage]
        if case .available(let values) = networkViewModel.processTraffic { traffic = values } else { traffic = [] }
        let measurements = ResourceHogAnalyzer.measurements(
            groups: processesViewModel.applicationGroups,
            processNetworkUsage: traffic,
            thresholds: settings.resourceHogThresholds
        )
        let events = await resourceHogAlertEvaluator.evaluate(
            measurements: measurements,
            at: Date(),
            enabled: settings.hogAlertsEnabled,
            duration: settings.alertDuration,
            cooldown: settings.alertCooldown
        )
        for event in events {
            alertCenter.record(event, postNotification: settings.notificationsEnabled)
        }
    }
}
