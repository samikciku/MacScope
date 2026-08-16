import Foundation
import IOKit

enum DiskMonitorError: Error, LocalizedError, Sendable {
    case missingCapacity

    var errorDescription: String? {
        switch self {
        case .missingCapacity: "The startup volume did not provide capacity information."
        }
    }
}

struct DiskIOCounterSnapshot: Equatable, Sendable {
    let timestamp: TimeInterval
    let readBytes: UInt64
    let writtenBytes: UInt64
    let deviceCount: Int
}

enum DiskIOCalculations {
    static func activity(
        current: DiskIOCounterSnapshot,
        previous: DiskIOCounterSnapshot?
    ) -> DiskStats.IOActivity {
        guard let previous,
              current.timestamp > previous.timestamp,
              current.readBytes >= previous.readBytes,
              current.writtenBytes >= previous.writtenBytes else {
            return .init(
                totalReadBytes: current.readBytes,
                totalWrittenBytes: current.writtenBytes,
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                deviceCount: current.deviceCount
            )
        }
        let elapsed = current.timestamp - previous.timestamp
        return .init(
            totalReadBytes: current.readBytes,
            totalWrittenBytes: current.writtenBytes,
            readBytesPerSecond: Double(current.readBytes - previous.readBytes) / elapsed,
            writeBytesPerSecond: Double(current.writtenBytes - previous.writtenBytes) / elapsed,
            deviceCount: current.deviceCount
        )
    }
}

actor DiskMonitor: DiskMonitorProtocol {
    private let volumeURL: URL
    private var previousIOSnapshot: DiskIOCounterSnapshot?

    init(volumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true)) {
        self.volumeURL = volumeURL
    }

    func currentStats() async throws -> DiskStats {
        let values = try volumeURL.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsReadOnlyKey
        ])
        guard let total = values.volumeTotalCapacity, total >= 0,
              let available = values.volumeAvailableCapacityForImportantUsage, available >= 0 else {
            throw DiskMonitorError.missingCapacity
        }
        let timestamp = Date()
        let ioActivity: MetricAvailability<DiskStats.IOActivity>
        switch readIOCounters(at: timestamp) {
        case .available(let snapshot):
            ioActivity = .available(DiskIOCalculations.activity(current: snapshot, previous: previousIOSnapshot))
            previousIOSnapshot = snapshot
        case .unavailable(let reason):
            ioActivity = .unavailable(reason: reason)
        case .unsupported(let reason):
            ioActivity = .unsupported(reason: reason)
        }
        return DiskStats(
            timestamp: timestamp,
            volumeName: values.volumeName ?? volumeURL.lastPathComponent,
            mountPath: volumeURL.path,
            totalBytes: UInt64(total),
            availableBytes: UInt64(available),
            isReadOnly: values.volumeIsReadOnly ?? false,
            ioActivity: ioActivity
        )
    }

    private func readIOCounters(at timestamp: Date) -> MetricAvailability<DiskIOCounterSnapshot> {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else {
            return .unavailable(reason: "Unable to create an IOKit block-storage query.")
        }
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            return .unavailable(reason: "Unable to enumerate block-storage drivers (IOKit error \(result)).")
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0
        var count = 0
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            guard let property = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue(),
            let statistics = property as? [String: Any],
            let read = statistics["Bytes (Read)"] as? NSNumber,
            let written = statistics["Bytes (Write)"] as? NSNumber else { continue }
            totalRead = addingClamping(totalRead, read.uint64Value)
            totalWritten = addingClamping(totalWritten, written.uint64Value)
            count += 1
        }
        guard count > 0 else {
            return .unsupported(reason: "No block-storage driver exposed public I/O statistics.")
        }
        return .available(.init(
            timestamp: timestamp.timeIntervalSinceReferenceDate,
            readBytes: totalRead,
            writtenBytes: totalWritten,
            deviceCount: count
        ))
    }

    private func addingClamping(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
