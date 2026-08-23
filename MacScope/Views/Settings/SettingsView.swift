import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var settings: MonitoringSettings
    @ObservedObject var diagnostics: MonitoringDiagnostics
    @ObservedObject var systemViewModel: SystemViewModel
    @ObservedObject var gpuViewModel: GPUViewModel
    @State private var reportCopied = false

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
                if DistributionChannel.allowsExperimentalGPU {
                    Toggle("Enable experimental GPU metrics", isOn: $settings.experimentalGPUEnabled)
                    Text("Uses undocumented Apple Silicon AGX IORegistry fields that can change or disappear after macOS updates. Public Metal remains the default.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if DistributionChannel.allowsPrivilegedGPUHelper {
                    Toggle("Enable advanced GPU helper", isOn: $settings.advancedGPUHelperEnabled)
                        .disabled(!settings.experimentalGPUEnabled)
                    Text("Exposes the Developer ID–gated helper option. Installation still requires explicit administrator approval and can be removed from the GPU screen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if DistributionChannel.isMacAppStore {
                    Text("This Mac App Store build uses public Metal GPU information and does not install privileged helpers or use experimental GPU metrics.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Diagnostics") {
                LabeledContent("Monitoring", value: diagnostics.lifecycleState.rawValue)
                if let wake = diagnostics.lastWakeDate {
                    LabeledContent("Last start or wake") {
                        Text(wake, format: .dateTime.year().month().day().hour().minute().second())
                    }
                }
                if diagnostics.orderedCollectors.isEmpty {
                    Text("Collecting the first samples…").foregroundStyle(.secondary)
                } else {
                    ForEach(diagnostics.orderedCollectors) { item in collectorRow(item) }
                }
                Button(reportCopied ? "Diagnostics Copied" : "Copy Sanitized Diagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diagnosticReport, forType: .string)
                    reportCopied = true
                }
                Text("The report excludes process names, users, arguments, file paths, and network endpoints.")
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

    private var systemInfo: SystemInfo? {
        if case .loaded(let info) = systemViewModel.state { return info }
        return nil
    }

    private var diagnosticReport: String {
        DiagnosticReport.make(from: .init(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development",
            systemInfo: systemInfo,
            gpuSource: gpuViewModel.source,
            lifecycle: diagnostics.lifecycleState,
            collectors: diagnostics.orderedCollectors
        ))
    }

    private func collectorRow(_ item: CollectorDiagnostic) -> some View {
        let status = item.status(at: Date())
        return HStack {
            Text(item.collector.title)
            Spacer()
            Text("\(item.sampleCount) samples · avg \(duration(item.averageDuration))")
                .foregroundStyle(.secondary).monospacedDigit()
            Text(status.title).foregroundStyle(statusColor(status))
        }
        .accessibilityElement(children: .combine)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int(seconds * 1_000)) ms" : seconds.formatted(.number.precision(.fractionLength(2))) + " s"
    }

    private func statusColor(_ status: CollectorDiagnostic.Status) -> Color {
        switch status {
        case .healthy: .green
        case .collecting: .secondary
        case .stale: .orange
        case .failing: .red
        }
    }
}
