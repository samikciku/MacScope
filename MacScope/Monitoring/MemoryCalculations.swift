struct MemoryPageCounts: Equatable, Sendable {
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let purgeable: UInt64
}

struct MemoryByteBreakdown: Equatable, Sendable {
    let used: UInt64
    let available: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64
    let compressed: UInt64
    let purgeable: UInt64
}

struct MemoryPagingSnapshot: Equatable, Sendable {
    let timestamp: Double
    let pageIns: UInt64
    let pageOuts: UInt64
}

enum MemoryCalculations {
    /// Estimates reclaimable memory as free, inactive, and purgeable pages.
    /// Speculative pages are already included in Mach's `free_count`.
    static func bytes(
        totalBytes: UInt64,
        pageSize: UInt64,
        counts: MemoryPageCounts
    ) -> MemoryByteBreakdown {
        let free = multipliedClamping(counts.free, pageSize)
        let active = multipliedClamping(counts.active, pageSize)
        let inactive = multipliedClamping(counts.inactive, pageSize)
        let wired = multipliedClamping(counts.wired, pageSize)
        let compressed = multipliedClamping(counts.compressed, pageSize)
        let purgeable = multipliedClamping(counts.purgeable, pageSize)
        let reclaimable = addedClamping(addedClamping(free, inactive), purgeable)
        let available = Swift.min(totalBytes, reclaimable)

        return MemoryByteBreakdown(
            used: totalBytes - available,
            available: available,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            purgeable: purgeable
        )
    }

    static func paging(
        current: MemoryPagingSnapshot,
        previous: MemoryPagingSnapshot?,
        pageSize: UInt64
    ) -> MemoryStats.Paging {
        let pageInsBytes = multipliedClamping(current.pageIns, pageSize)
        let pageOutsBytes = multipliedClamping(current.pageOuts, pageSize)
        guard let previous else {
            return .init(
                pageInsBytes: pageInsBytes,
                pageOutsBytes: pageOutsBytes,
                pageInsBytesPerSecond: nil,
                pageOutsBytesPerSecond: nil
            )
        }
        let elapsed = current.timestamp - previous.timestamp
        guard elapsed > 0,
              current.pageIns >= previous.pageIns,
              current.pageOuts >= previous.pageOuts else {
            return .init(
                pageInsBytes: pageInsBytes,
                pageOutsBytes: pageOutsBytes,
                pageInsBytesPerSecond: nil,
                pageOutsBytesPerSecond: nil
            )
        }
        let insDelta = multipliedClamping(current.pageIns - previous.pageIns, pageSize)
        let outsDelta = multipliedClamping(current.pageOuts - previous.pageOuts, pageSize)
        return .init(
            pageInsBytes: pageInsBytes,
            pageOutsBytes: pageOutsBytes,
            pageInsBytesPerSecond: Double(insDelta) / elapsed,
            pageOutsBytesPerSecond: Double(outsDelta) / elapsed
        )
    }

    private static func multipliedClamping(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? .max : result.partialValue
    }

    private static func addedClamping(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
