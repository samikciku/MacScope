import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $appState.selection) { section in
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
