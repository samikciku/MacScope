import SwiftUI

@main
struct MacScopeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("MacScope", id: "main") {
            RootContainerView(settings: appState.settings)
                .environmentObject(appState)
                .frame(minWidth: 880, minHeight: 560)
                .task { appState.startMonitoring() }
        }
        .defaultSize(width: 1_080, height: 720)
        .commands {
            CommandMenu("Navigate") {
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                    if index < 9 {
                        Button(section.title) {
                            appState.selection = section
                        }
                        .keyboardShortcut(
                            KeyEquivalent(Character(String(index + 1))),
                            modifiers: .command
                        )
                    }
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh Now") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Window("MacScope Compact", id: "compact") {
            CompactMonitorView(
                memoryViewModel: appState.memoryViewModel,
                cpuViewModel: appState.cpuViewModel,
                gpuViewModel: appState.gpuViewModel,
                settings: appState.settings
            )
            .preferredColorScheme(appState.settings.appearance.colorScheme)
            .task { appState.startMonitoring() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 230, height: 210)

        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarContentView(
                memoryViewModel: appState.memoryViewModel,
                cpuViewModel: appState.cpuViewModel,
                processesViewModel: appState.processesViewModel
            )
            .task { appState.startMonitoring() }
        } label: {
            MenuBarLabelView(
                memoryViewModel: appState.memoryViewModel,
                cpuViewModel: appState.cpuViewModel
            )
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.showMenuBarItem },
            set: { appState.settings.showMenuBarItem = $0 }
        )
    }
}

private struct RootContainerView: View {
    @ObservedObject var settings: MonitoringSettings

    var body: some View {
        RootView()
            .preferredColorScheme(settings.appearance.colorScheme)
    }
}
