import SwiftUI

struct SystemView: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Reading system information…")
            case .failed(let message):
                ContentUnavailableView(
                    "System Information Unavailable",
                    systemImage: "desktopcomputer.trianglebadge.exclamationmark",
                    description: Text(message)
                )
            case .loaded(let info):
                details(info)
            }
        }
        .navigationTitle("System")
    }

    private func details(_ info: SystemInfo) -> some View {
        ScrollView {
            GroupBox("This Mac") {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    row("Model", info.modelName)
                    row("Processor", info.processorName)
                    row("Architecture", info.architecture)
                    row("Logical cores", info.logicalCoreCount.formatted())
                    row("Physical memory", ByteFormatter.string(fromByteCount: info.physicalMemoryBytes))
                    row("macOS", info.operatingSystemVersion)
                    row("Uptime", Duration.seconds(info.uptimeSeconds).formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated)))
                }
                .padding(.top, 8)
                .textSelection(.enabled)
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
            Text(value)
        }
        .accessibilityElement(children: .combine)
    }
}
