import Charts
import SwiftUI

struct MemoryHistoryChart: View {
    let history: [MemoryStats]

    var body: some View {
        GroupBox("Memory history") {
            if history.isEmpty {
                chartPlaceholder
            } else {
                Chart(history, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Used bytes", Double(sample.usedBytes)),
                        series: .value("Metric", "Used")
                    )
                    .foregroundStyle(by: .value("Metric", "Used"))
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Available bytes", Double(sample.availableBytes)),
                        series: .value("Metric", "Available")
                    )
                    .foregroundStyle(by: .value("Metric", "Available"))
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(Double.self), bytes >= 0 {
                                Text(ByteFormatter.string(fromByteCount: UInt64(bytes)))
                            }
                        }
                    }
                }
                .accessibilityLabel("Used and available memory history")
            }
        }
    }
}

struct CPUHistoryChart: View {
    let history: [CPUStats]

    var body: some View {
        GroupBox("CPU history") {
            if history.isEmpty {
                chartPlaceholder
            } else {
                Chart(history, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Utilization", sample.totalUsage)
                    )
                    .interpolationMethod(.linear)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(100))
                }
                .accessibilityLabel("Overall CPU utilization history")
            }
        }
    }
}

struct MemoryPagingHistoryChart: View {
    let history: [MemoryStats]

    var body: some View {
        GroupBox("Paging activity") {
            Chart(history, id: \.timestamp) { sample in
                if let rate = sample.paging.pageInsBytesPerSecond {
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Bytes per second", rate),
                        series: .value("Direction", "Page-ins")
                    )
                    .foregroundStyle(by: .value("Direction", "Page-ins"))
                }
                if let rate = sample.paging.pageOutsBytesPerSecond {
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Bytes per second", rate),
                        series: .value("Direction", "Page-outs")
                    )
                    .foregroundStyle(by: .value("Direction", "Page-outs"))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let rate = value.as(Double.self), rate >= 0 {
                            Text("\(ByteFormatter.string(fromByteCount: UInt64(rate)))/s")
                        }
                    }
                }
            }
            .accessibilityLabel("Page-in and page-out byte rates")
        }
    }
}

struct ProcessHistoryCharts: View {
    let history: [ProcessResourceSample]

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Memory history") {
                Chart(history, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Resident bytes", Double(sample.residentBytes))
                    )
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 130)
            }
            GroupBox("CPU history") {
                Chart(history, id: \.timestamp) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("CPU percent", sample.cpuPercent)
                    )
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 130)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Process resource history")
    }
}

struct CompactMemoryChart: View {
    let history: [MemoryStats]

    var body: some View {
        GroupBox("Memory trend") {
            Chart(history, id: \.timestamp) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Used bytes", Double(sample.usedBytes))
                )
                .foregroundStyle(.blue.opacity(0.35))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(minHeight: 105)
            .accessibilityLabel("Compact memory usage history")
        }
    }
}

struct CompactCPUChart: View {
    let history: [CPUStats]

    var body: some View {
        GroupBox("CPU trend") {
            Chart(history, id: \.timestamp) { sample in
                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Utilization", sample.totalUsage)
                )
                .foregroundStyle(.green.opacity(0.35))
            }
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(minHeight: 105)
            .accessibilityLabel("Compact CPU utilization history")
        }
    }
}

private var chartPlaceholder: some View {
    ContentUnavailableView(
        "Collecting History",
        systemImage: "chart.xyaxis.line",
        description: Text("Samples will appear here as they are collected.")
    )
}
