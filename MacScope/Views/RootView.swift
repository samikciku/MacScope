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
                onNavigate: { appState.navigate(to: $0) }
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
            GPUView(viewModel: appState.gpuViewModel, settings: appState.settings)
        case .settings:
            SettingsView(
                settings: appState.settings,
                diagnostics: appState.monitoringDiagnostics,
                systemViewModel: appState.systemViewModel,
                gpuViewModel: appState.gpuViewModel
            )
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

    var body: some View {
        VStack(spacing: 0) {
            Picker("Applications view", selection: $appState.applicationsTab) {
                ForEach(ApplicationsTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 430).padding(12)
            Divider()
            switch appState.applicationsTab {
            case .resourceHogs:
                ResourceHogsView(
                    processesViewModel: appState.processesViewModel,
                    networkViewModel: appState.networkViewModel,
                    settings: appState.settings,
                    alertCenter: appState.alertCenter
                )
            case .macScope: SelfMonitoringView(viewModel: appState.processesViewModel)
            case .running: ProcessesView(viewModel: appState.processesViewModel)
            }
        }
        .navigationTitle("Applications")
    }
}

private struct PerformanceHubView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Performance metric", selection: $appState.performanceTab) {
                ForEach(PerformanceTab.availableCases) { tab in Text(tab.rawValue).tag(tab) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 650).padding(12)
            Divider()
            switch appState.performanceTab {
            case .cpu: CPUView(viewModel: appState.cpuViewModel)
            case .gpu: GPUView(viewModel: appState.gpuViewModel, settings: appState.settings)
            case .energy: EnergyView(viewModel: appState.processesViewModel)
            case .thermal: ThermalView(viewModel: appState.thermalViewModel)
            case .battery: BatteryView(viewModel: appState.batteryViewModel)
            case .memory: MemoryView(viewModel: appState.memoryViewModel, processesViewModel: appState.processesViewModel)
            }
        }
        .navigationTitle("Performance")
    }
}

private struct EventsHubView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Events view", selection: $appState.eventsTab) {
                ForEach(EventsTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 320).padding(12)
            Divider()
            if appState.eventsTab == .timeline {
                SystemEventTimelineView(alertCenter: appState.alertCenter)
            } else {
                AlertsView(alertCenter: appState.alertCenter, settings: appState.settings)
            }
        }
        .navigationTitle("Events")
    }
}
