import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var memoryViewModel: MemoryViewModel
    @ObservedObject var cpuViewModel: CPUViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.67percent")
            Text(label)
                .monospacedDigit()
        }
        .accessibilityLabel("MacScope, \(accessibleLabel)")
    }

    private var label: String {
        "RAM \(memoryPercent)  CPU \(cpuPercent)"
    }

    private var accessibleLabel: String {
        "memory \(memoryPercent), CPU \(cpuPercent)"
    }

    private var memoryPercent: String {
        guard case .loaded(let stats) = memoryViewModel.state, stats.totalBytes > 0 else { return "—" }
        return (Double(stats.usedBytes) / Double(stats.totalBytes))
            .formatted(.percent.precision(.fractionLength(0)))
    }

    private var cpuPercent: String {
        guard case .loaded(let stats) = cpuViewModel.state else { return "—" }
        return stats.totalUsage.formatted(.percent.precision(.fractionLength(0)))
    }
}
