import AppKit
import Charts
import SwiftUI

struct DiskView: View {
    @ObservedObject var viewModel: DiskViewModel
    @State private var pendingTrashEntry: StorageEntry?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Reading disk capacity…")
            case .failed(let message):
                ContentUnavailableView(
                    "Disk Capacity Unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(message)
                )
            case .loaded(let stats):
                content(stats)
            }
        }
        .navigationTitle("Disk")
        .alert("Move to Trash?", isPresented: trashConfirmationPresented, presenting: pendingTrashEntry) { entry in
            Button("Cancel", role: .cancel) { pendingTrashEntry = nil }
            Button("Move to Trash", role: .destructive) {
                pendingTrashEntry = nil
                Task { await viewModel.moveToTrash(entry) }
            }
        } message: { entry in
            Text("Move \(entry.name) (\(ByteFormatter.string(fromByteCount: entry.byteCount))) to Trash? You can recover it from Trash until it is emptied.")
        }
        .alert("Storage Scan", isPresented: storageMessagePresented) {
            Button("OK") { viewModel.storageMessage = nil }
        } message: {
            Text(viewModel.storageMessage ?? "")
        }
    }

    private func content(_ stats: DiskStats) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox(stats.volumeName) {
                    Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                        row("Mount point", stats.mountPath)
                        row("Total", ByteFormatter.string(fromByteCount: stats.totalBytes))
                        row("Used", ByteFormatter.string(fromByteCount: stats.usedBytes))
                        row("Available", ByteFormatter.string(fromByteCount: stats.availableBytes))
                        row("Used percentage", stats.usedFraction.formatted(.percent.precision(.fractionLength(1))))
                        row("Read only", stats.isReadOnly ? "Yes" : "No")
                        ioRows(stats.ioActivity)
                    }
                    .padding(.top, 8)
                    ProgressView(value: stats.usedFraction)
                        .tint(stats.usedFraction >= 0.9 ? .red : .accentColor)
                        .accessibilityLabel("Disk space used")
                }

                GroupBox("Available capacity history") {
                    Chart(viewModel.history, id: \.timestamp) { sample in
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Available bytes", Double(sample.availableBytes))
                        )
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
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
                    .frame(height: 220)
                    .accessibilityLabel("Available disk capacity history")
                }

                storageBrowser

                DiskIOHistoryChart(history: viewModel.history)

                Text("I/O is aggregated across block-storage drivers exposed by IOKit; it is not attributed to this volume or individual processes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var storageBrowser: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Choose Folder…") { chooseFolder() }
                    if let folder = viewModel.scannedFolder {
                        Text(folder.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(folder.path(percentEncoded: false))
                    } else {
                        Text("Select a folder to analyze")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Show", selection: $viewModel.storageFilter) {
                        ForEach(StorageEntryFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .frame(width: 145)
                }

                if viewModel.isScanning {
                    ProgressView("Calculating folder sizes…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if viewModel.scannedFolder == nil {
                    ContentUnavailableView(
                        "No Folder Selected",
                        systemImage: "folder.badge.questionmark",
                        description: Text("MacScope scans only the folder you choose.")
                    )
                    .frame(minHeight: 180)
                } else if viewModel.visibleStorageEntries.isEmpty {
                    ContentUnavailableView("No Matching Items", systemImage: "folder")
                        .frame(minHeight: 180)
                } else {
                    Table(viewModel.visibleStorageEntries) {
                        TableColumn("Name") { entry in
                            Label(entry.name, systemImage: entry.isDirectory ? "folder.fill" : "doc.fill")
                                .lineLimit(1)
                                .help(entry.url.path(percentEncoded: false))
                        }
                        .width(min: 220, ideal: 360)

                        TableColumn("Type") { entry in
                            Text(entry.isDirectory ? "Folder" : "File")
                        }
                        .width(70)

                        TableColumn("Size (largest first)") { entry in
                            Text(ByteFormatter.string(fromByteCount: entry.byteCount))
                                .monospacedDigit()
                        }
                        .width(min: 120, ideal: 140)

                        TableColumn("Action") { entry in
                            Button("Move to Trash…", role: .destructive) { pendingTrashEntry = entry }
                                .buttonStyle(.borderless)
                        }
                        .width(min: 110, ideal: 125)
                    }
                    .frame(height: 330)
                }

                Text("Sizes include each top-level folder's contents. Items are sorted from largest to smallest. Removal always uses macOS Trash.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Storage analyzer", systemImage: "externaldrive.fill.badge.magnifyingglass")
        }
    }

    private var trashConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingTrashEntry != nil },
            set: { if !$0 { pendingTrashEntry = nil } }
        )
    }

    private var storageMessagePresented: Binding<Bool> {
        Binding(
            get: { viewModel.storageMessage != nil },
            set: { if !$0 { viewModel.storageMessage = nil } }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Folder to Analyze"
        panel.prompt = "Scan Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        Task { await viewModel.scan(folder: folder) }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
            Text(value).monospacedDigit().textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func ioRows(_ availability: MetricAvailability<DiskStats.IOActivity>) -> some View {
        switch availability {
        case .available(let activity):
            row("Read rate", rate(activity.readBytesPerSecond))
            row("Write rate", rate(activity.writeBytesPerSecond))
            row("Total read", ByteFormatter.string(fromByteCount: activity.totalReadBytes))
            row("Total written", ByteFormatter.string(fromByteCount: activity.totalWrittenBytes))
            row("Block devices", activity.deviceCount.formatted())
        case .unavailable(let reason), .unsupported(let reason):
            GridRow {
                Text("Disk I/O")
                Text("Unavailable").foregroundStyle(.secondary).help(reason)
            }
        }
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value >= 0 else { return "Collecting…" }
        return "\(ByteFormatter.string(fromByteCount: UInt64(value)))/s"
    }
}

private struct DiskIOHistoryChart: View {
    let history: [DiskStats]

    var body: some View {
        GroupBox("Disk I/O history") {
            Chart(history, id: \.timestamp) { sample in
                if case .available(let activity) = sample.ioActivity {
                    if let read = activity.readBytesPerSecond {
                        LineMark(x: .value("Time", sample.timestamp), y: .value("Bytes per second", read), series: .value("Direction", "Read"))
                            .foregroundStyle(by: .value("Direction", "Read"))
                    }
                    if let write = activity.writeBytesPerSecond {
                        LineMark(x: .value("Time", sample.timestamp), y: .value("Bytes per second", write), series: .value("Direction", "Write"))
                            .foregroundStyle(by: .value("Direction", "Write"))
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(height: 220)
            .accessibilityLabel("Aggregate block-device read and write rates")
        }
    }
}
