import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var settings: MonitoringSettings

    var body: some View {
        Form {
            Toggle("Show menu-bar monitor", isOn: $settings.showMenuBarItem)

            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }

            Picker("System refresh interval", selection: $settings.refreshInterval) {
                ForEach(SamplingInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }

            LabeledContent("Process refresh interval") {
                Text(processIntervalDescription)
                    .foregroundStyle(.secondary)
            }

            Text("Process enumeration is capped at a minimum two-second interval to limit monitoring overhead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Process refreshes no faster than every two seconds to reduce overhead")

            Section("Compact Monitor") {
                Button("Open Compact Monitor") { openWindow(id: "compact") }
                Toggle("Always on top", isOn: $settings.compactAlwaysOnTop)
                LabeledContent("Opacity") {
                    Text(settings.compactOpacity, format: .percent.precision(.fractionLength(0)))
                }
                Slider(value: $settings.compactOpacity, in: 0.5...1, step: 0.05)
                Toggle("Show GPU", isOn: $settings.compactShowGPU)
                Toggle("Show swap", isOn: $settings.compactShowSwap)
            }

            Section("Advanced and Experimental") {
                Toggle("Enable experimental GPU metrics", isOn: $settings.experimentalGPUEnabled)
                Text("Uses undocumented Apple Silicon AGX IORegistry fields that can change or disappear after macOS updates. Public Metal remains the default.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("Enable advanced GPU helper", isOn: $settings.advancedGPUHelperEnabled)
                    .disabled(!settings.experimentalGPUEnabled)
                Text("Exposes the Developer ID–gated helper option. Installation still requires explicit administrator approval and can be removed from the GPU screen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private var processIntervalDescription: String {
        let seconds = Swift.max(2, settings.refreshInterval.rawValue)
        return "\(Int(seconds)) seconds"
    }
}
