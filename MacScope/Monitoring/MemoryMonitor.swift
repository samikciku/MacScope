import Darwin
import Foundation

enum MemoryMonitorError: Error, Equatable, LocalizedError, Sendable {
    case pageSize(kern_return_t)
    case hostStatistics(kern_return_t)
    case swapUsage(Int32)

    var errorDescription: String? {
        switch self {
        case .pageSize(let code):
            "Unable to read the host page size (Mach error \(code))."
        case .hostStatistics(let code):
            "Unable to read host memory statistics (Mach error \(code))."
        case .swapUsage(let code):
            "Unable to read swap usage (errno \(code))."
        }
    }
}

actor MemoryMonitor: MemoryMonitorProtocol {
    private var previousPagingSnapshot: MemoryPagingSnapshot?
    private let pressureMonitor: MemoryPressureMonitor

    init(pressureMonitor: MemoryPressureMonitor = MemoryPressureMonitor()) {
        self.pressureMonitor = pressureMonitor
    }

    func currentStats() async throws -> MemoryStats {
        let host = mach_host_self()
        var pageSize: vm_size_t = 0
        let pageResult = host_page_size(host, &pageSize)
        guard pageResult == KERN_SUCCESS else {
            throw MemoryMonitorError.pageSize(pageResult)
        }

        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let statsResult = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard statsResult == KERN_SUCCESS else {
            throw MemoryMonitorError.hostStatistics(statsResult)
        }

        let timestamp = Date()
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let breakdown = MemoryCalculations.bytes(
            totalBytes: totalBytes,
            pageSize: UInt64(pageSize),
            counts: MemoryPageCounts(
                free: UInt64(vmStats.free_count),
                active: UInt64(vmStats.active_count),
                inactive: UInt64(vmStats.inactive_count),
                wired: UInt64(vmStats.wire_count),
                compressed: UInt64(vmStats.compressor_page_count),
                purgeable: UInt64(vmStats.purgeable_count)
            )
        )
        let pagingSnapshot = MemoryPagingSnapshot(
            timestamp: timestamp.timeIntervalSinceReferenceDate,
            pageIns: UInt64(vmStats.pageins),
            pageOuts: UInt64(vmStats.pageouts)
        )
        let paging = MemoryCalculations.paging(
            current: pagingSnapshot,
            previous: previousPagingSnapshot,
            pageSize: UInt64(pageSize)
        )
        previousPagingSnapshot = pagingSnapshot
        let swap = readSwapUsage()

        return MemoryStats(
            timestamp: timestamp,
            totalBytes: totalBytes,
            usedBytes: breakdown.used,
            availableBytes: breakdown.available,
            freeBytes: breakdown.free,
            wiredBytes: breakdown.wired,
            compressedBytes: breakdown.compressed,
            activeBytes: breakdown.active,
            inactiveBytes: breakdown.inactive,
            purgeableBytes: breakdown.purgeable,
            paging: paging,
            swap: swap,
            pressure: pressureMonitor.currentState()
        )
    }

    private func readSwapUsage() -> MetricAvailability<MemoryStats.Swap> {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else {
            return .unavailable(reason: MemoryMonitorError.swapUsage(errno).localizedDescription)
        }
        return .available(
            MemoryStats.Swap(totalBytes: usage.xsu_total, usedBytes: usage.xsu_used)
        )
    }
}
