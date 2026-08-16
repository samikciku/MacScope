import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selection: AppSection? = .dashboard
    let memoryViewModel: MemoryViewModel
    let cpuViewModel: CPUViewModel
    let processesViewModel: ProcessesViewModel
    let gpuViewModel: GPUViewModel
    let settings: MonitoringSettings
    let systemViewModel: SystemViewModel
    let diskViewModel: DiskViewModel
    let networkViewModel: NetworkViewModel
    let batteryViewModel: BatteryViewModel
    let thermalViewModel: ThermalViewModel
    let alertCenter: AlertCenter
    let monitoringDiagnostics: MonitoringDiagnostics
    private let alertEvaluator: ResourceAlertEvaluator
    private let resourceHogAlertEvaluator: ResourceHogAlertEvaluator
    private var monitoringCoordinator: MonitoringCoordinator?

    init(
        memoryViewModel: MemoryViewModel = MemoryViewModel(),
        cpuViewModel: CPUViewModel = CPUViewModel(),
        processesViewModel: ProcessesViewModel = ProcessesViewModel(),
        gpuViewModel: GPUViewModel = GPUViewModel(),
        settings: MonitoringSettings = MonitoringSettings(),
        systemViewModel: SystemViewModel = SystemViewModel(),
        diskViewModel: DiskViewModel = DiskViewModel(),
        networkViewModel: NetworkViewModel = NetworkViewModel(),
        batteryViewModel: BatteryViewModel = BatteryViewModel(),
        thermalViewModel: ThermalViewModel = ThermalViewModel(),
        alertCenter: AlertCenter = AlertCenter(),
        monitoringDiagnostics: MonitoringDiagnostics = MonitoringDiagnostics(),
        alertEvaluator: ResourceAlertEvaluator = ResourceAlertEvaluator(),
        resourceHogAlertEvaluator: ResourceHogAlertEvaluator = ResourceHogAlertEvaluator()
    ) {
        self.memoryViewModel = memoryViewModel
        self.cpuViewModel = cpuViewModel
        self.processesViewModel = processesViewModel
        self.gpuViewModel = gpuViewModel
        self.settings = settings
        self.systemViewModel = systemViewModel
        self.diskViewModel = diskViewModel
        self.networkViewModel = networkViewModel
        self.batteryViewModel = batteryViewModel
        self.thermalViewModel = thermalViewModel
        self.alertCenter = alertCenter
        self.monitoringDiagnostics = monitoringDiagnostics
        self.alertEvaluator = alertEvaluator
        self.resourceHogAlertEvaluator = resourceHogAlertEvaluator
    }

    func startMonitoring() {
        if monitoringCoordinator == nil {
            monitoringCoordinator = MonitoringCoordinator(
                memoryViewModel: memoryViewModel,
                cpuViewModel: cpuViewModel,
                processesViewModel: processesViewModel,
                gpuViewModel: gpuViewModel,
                systemViewModel: systemViewModel,
                diskViewModel: diskViewModel,
                networkViewModel: networkViewModel,
                batteryViewModel: batteryViewModel,
                thermalViewModel: thermalViewModel,
                settings: settings,
                alertCenter: alertCenter,
                alertEvaluator: alertEvaluator,
                resourceHogAlertEvaluator: resourceHogAlertEvaluator,
                diagnostics: monitoringDiagnostics
            )
        }
        monitoringCoordinator?.start()
    }

    func refreshAll() async {
        async let memory: Void = memoryViewModel.refresh()
        async let cpu: Void = cpuViewModel.refresh()
        async let processes: Void = processesViewModel.refresh()
        async let gpu: Void = gpuViewModel.refresh()
        async let system: Void = systemViewModel.refresh()
        async let disk: Void = diskViewModel.refresh()
        async let network: Void = networkViewModel.refresh()
        async let battery: Void = batteryViewModel.refresh()
        async let thermal: Void = thermalViewModel.refresh()
        _ = await (memory, cpu, processes, gpu, system, disk, network, battery, thermal)
    }
}

enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case applications
    case performance
    case events
    case processes
    case memory
    case cpu
    case gpu
    case system
    case disk
    case network
    case battery
    case thermal
    case timeline
    case energy
    case resourceHogs
    case selfMonitoring
    case alerts
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: "Overview"
        case .applications: "Applications"
        case .performance: "Performance"
        case .events: "Events"
        case .processes: "Processes"
        case .memory: "Memory"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .system: "System"
        case .disk: "Disk"
        case .network: "Network"
        case .battery: "Battery"
        case .thermal: "Thermal"
        case .timeline: "Timeline"
        case .energy: "Energy"
        case .resourceHogs: "Resource Hogs"
        case .selfMonitoring: "MacScope"
        case .alerts: "Alerts"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .applications: "square.stack.3d.up"
        case .performance: "waveform.path.ecg"
        case .events: "clock.badge.exclamationmark"
        case .processes: "list.bullet.rectangle"
        case .memory: "memorychip"
        case .cpu: "cpu"
        case .gpu: "display"
        case .system: "desktopcomputer"
        case .disk: "internaldrive"
        case .network: "network"
        case .battery: "battery.75percent"
        case .thermal: "thermometer.medium"
        case .timeline: "clock.arrow.circlepath"
        case .energy: "bolt"
        case .resourceHogs: "flame"
        case .selfMonitoring: "scope"
        case .alerts: "bell.badge"
        case .settings: "gearshape"
        }
    }

    static let primaryNavigation: [AppSection] = [
        .dashboard, .applications, .performance, .disk, .network, .events, .settings
    ]
}
