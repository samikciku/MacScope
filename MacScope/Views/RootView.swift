import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppSection.primaryNavigation, selection: $appState.selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                }
                .accessibilityLabel(section.title)
            }
            .navigationTitle("MacScope")
        } detail: {
            sectionView(for: appState.selection ?? .dashboard)
        }
    }

    @ViewBuilder
    private func sectionView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView(
                memoryViewModel: appState.memoryViewModel,
                cpuViewModel: appState.cpuViewModel,
                processesViewModel: appState.processesViewModel,
                gpuViewModel: appState.gpuViewModel,
                diskViewModel: appState.diskViewModel,
                networkViewModel: appState.networkViewModel,
                batteryViewModel: appState.batteryViewModel,
                thermalViewModel: appState.thermalViewModel,
                alertCenter: appState.alertCenter,
                onNavigate: { appState.selection = $0 }
            )
        case .applications:
            ApplicationsHubView(appState: appState)
        case .performance:
            PerformanceHubView(appState: appState)
        case .events:
            EventsHubView(appState: appState)
        case .memory:
            MemoryView(
                viewModel: appState.memoryViewModel,
                processesViewModel: appState.processesViewModel
            )
        case .cpu:
            CPUView(viewModel: appState.cpuViewModel)
        case .processes:
            ProcessesView(viewModel: appState.processesViewModel)
        case .gpu:
            GPUView(viewModel: appState.gpuViewModel)
        case .settings:
            SettingsView(settings: appState.settings)
        case .system:
            SystemView(viewModel: appState.systemViewModel)
        case .disk:
            DiskView(viewModel: appState.diskViewModel)
        case .network:
            NetworkView(viewModel: appState.networkViewModel, processesViewModel: appState.processesViewModel)
        case .battery:
            BatteryView(viewModel: appState.batteryViewModel)
        case .thermal:
            ThermalView(viewModel: appState.thermalViewModel)
        case .timeline:
            SystemEventTimelineView(alertCenter: appState.alertCenter)
        case .energy:
            EnergyView(viewModel: appState.processesViewModel)
        case .resourceHogs:
            ResourceHogsView(
                processesViewModel: appState.processesViewModel,
                networkViewModel: appState.networkViewModel,
                settings: appState.settings,
                alertCenter: appState.alertCenter
            )
        case .selfMonitoring:
            SelfMonitoringView(viewModel: appState.processesViewModel)
        case .alerts:
            AlertsView(alertCenter: appState.alertCenter, settings: appState.settings)
        }
    }
}

private struct ApplicationsHubView: View {
    @ObservedObject var appState: AppState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Applications view", selection: $tab) {
                Text("Running").tag(0)
                Text("Resource Hogs").tag(1)
                Text("MacScope").tag(2)
            }
            .pickerStyle(.segmented).frame(maxWidth: 430).padding(12)
            Divider()
            switch tab {
            case 1:
                ResourceHogsView(
                    processesViewModel: appState.processesViewModel,
                    networkViewModel: appState.networkViewModel,
                    settings: appState.settings,
                    alertCenter: appState.alertCenter
                )
            case 2: SelfMonitoringView(viewModel: appState.processesViewModel)
            default: ProcessesView(viewModel: appState.processesViewModel)
            }
        }
        .navigationTitle("Applications")
    }
}

private struct PerformanceHubView: View {
    @ObservedObject var appState: AppState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Performance metric", selection: $tab) {
                Text("Memory").tag(0)
                Text("CPU").tag(1)
                Text("GPU").tag(2)
                Text("Energy").tag(3)
                Text("Thermal").tag(4)
                Text("Battery").tag(5)
            }
            .pickerStyle(.segmented).frame(maxWidth: 650).padding(12)
            Divider()
            switch tab {
            case 1: CPUView(viewModel: appState.cpuViewModel)
            case 2: GPUView(viewModel: appState.gpuViewModel)
            case 3: EnergyView(viewModel: appState.processesViewModel)
            case 4: ThermalView(viewModel: appState.thermalViewModel)
            case 5: BatteryView(viewModel: appState.batteryViewModel)
            default: MemoryView(viewModel: appState.memoryViewModel, processesViewModel: appState.processesViewModel)
            }
        }
        .navigationTitle("Performance")
    }
}

private struct EventsHubView: View {
    @ObservedObject var appState: AppState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Events view", selection: $tab) {
                Text("Timeline").tag(0)
                Text("Alert Rules").tag(1)
            }
            .pickerStyle(.segmented).frame(maxWidth: 320).padding(12)
            Divider()
            if tab == 0 {
                SystemEventTimelineView(alertCenter: appState.alertCenter)
            } else {
                AlertsView(alertCenter: appState.alertCenter, settings: appState.settings)
            }
        }
        .navigationTitle("Events")
    }
}
