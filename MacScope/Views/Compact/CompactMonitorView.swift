import AppKit
import SwiftUI

struct CompactMonitorView: View {
    @ObservedObject var memoryViewModel: MemoryViewModel
    @ObservedObject var cpuViewModel: CPUViewModel
    @ObservedObject var gpuViewModel: GPUViewModel
    @ObservedObject var settings: MonitoringSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("MacScope", systemImage: "scope")
                    .font(.headline)
                Spacer()
            }
            Divider()
            metric("CPU", value: cpuText, symbol: "cpu")
            metric("RAM", value: memoryText, symbol: "memorychip")
            if settings.compactShowGPU {
                metric("GPU", value: gpuText, symbol: "display")
            }
            if settings.compactShowSwap {
                metric("Swap", value: swapText, symbol: "arrow.left.arrow.right")
            }
        }
        .padding(14)
        .frame(minWidth: 210)
        .background(.regularMaterial)
        .background(CompactWindowConfigurator(settings: settings))
        .accessibilityElement(children: .contain)
    }

    private func metric(_ name: String, value: String, symbol: String) -> some View {
        HStack {
            Label(name, systemImage: symbol)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private var cpuText: String {
        guard case .loaded(let stats) = cpuViewModel.state else { return "—" }
        return stats.totalUsage.formatted(.percent.precision(.fractionLength(0)))
    }

    private var memoryText: String {
        guard case .loaded(let stats) = memoryViewModel.state else { return "—" }
        return ByteFormatter.string(fromByteCount: stats.usedBytes)
    }

    private var swapText: String {
        guard case .loaded(let stats) = memoryViewModel.state else { return "—" }
        switch stats.swap {
        case .available(let swap): return ByteFormatter.string(fromByteCount: swap.usedBytes)
        case .unavailable: return "Unavailable"
        case .unsupported: return "Unsupported"
        }
    }

    private var gpuText: String {
        guard case .loaded(let stats) = gpuViewModel.state else { return "—" }
        switch stats.utilization {
        case .available(let value): return value.formatted(.percent.precision(.fractionLength(0)))
        case .unavailable: return "Unavailable"
        case .unsupported: return "Unsupported"
        }
    }
}

private struct CompactWindowConfigurator: NSViewRepresentable {
    @ObservedObject var settings: MonitoringSettings

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.level = settings.compactAlwaysOnTop ? .floating : .normal
        window.alphaValue = settings.compactOpacity
        window.isOpaque = false
        window.collectionBehavior.insert(.canJoinAllSpaces)
    }
}
