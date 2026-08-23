import Foundation

@MainActor
final class DiskViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(DiskStats)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var history: [DiskStats] = []
    @Published private(set) var storageEntries: [StorageEntry] = []
    @Published private(set) var scannedFolder: URL?
    @Published private(set) var isScanning = false
    @Published var storageFilter: StorageEntryFilter = .all
    @Published var storageMessage: String?
    private let monitor: any DiskMonitorProtocol
    private let storageScanner = StorageScanner()
    private var historyBuffer = RingBuffer<DiskStats>(capacity: 300)

    init(monitor: any DiskMonitorProtocol = DiskMonitor()) {
        self.monitor = monitor
    }

    func refresh() async {
        do {
            let stats = try await monitor.currentStats()
            historyBuffer.append(stats)
            history = Array(historyBuffer)
            state = .loaded(stats)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetSamplingBaseline() async {
        await monitor.resetBaseline()
    }

    var visibleStorageEntries: [StorageEntry] {
        switch storageFilter {
        case .all: storageEntries
        case .files: storageEntries.filter { !$0.isDirectory }
        case .folders: storageEntries.filter(\.isDirectory)
        }
    }

    func scan(folder: URL) async {
        isScanning = true
        storageMessage = nil
        do {
            storageEntries = try await storageScanner.scan(folder.standardizedFileURL)
            scannedFolder = folder.standardizedFileURL
        } catch is CancellationError {
            storageMessage = "Storage scan cancelled."
        } catch {
            storageMessage = "Could not scan this folder: \(error.localizedDescription)"
        }
        isScanning = false
    }

    func moveToTrash(_ entry: StorageEntry) async {
        guard let root = scannedFolder?.standardizedFileURL,
              entry.url.standardizedFileURL.deletingLastPathComponent() == root else {
            storageMessage = "MacScope refused to remove an item outside the selected folder."
            return
        }
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: entry.url, resultingItemURL: &resultingURL)
            storageMessage = "Moved \(entry.name) to Trash."
            await scan(folder: root)
        } catch {
            storageMessage = "Could not move \(entry.name) to Trash: \(error.localizedDescription)"
        }
    }
}
