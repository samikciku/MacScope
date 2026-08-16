import Foundation

struct MemoryReclaimReport: Equatable, Sendable {
    let targetName: String
    let estimatedResidentBytes: UInt64
    let before: MemoryStats
    let after: MemoryStats

    var availableChange: Int64 { signedDifference(after.availableBytes, before.availableBytes) }
    var freeChange: Int64 { signedDifference(after.freeBytes, before.freeBytes) }
    var purgeableChange: Int64 { signedDifference(after.purgeableBytes, before.purgeableBytes) }

    var explanation: String {
        if availableChange > 0 {
            return "Available memory increased. This is the most useful indication that macOS made memory reusable."
        }
        if freeChange > 0 || purgeableChange > 0 {
            return "Free or purgeable memory increased even though total available memory did not increase during this sample."
        }
        return "No immediate increase was measured. macOS may retain reusable caches, the process may still be exiting, or other activity may have used the released memory."
    }

    private func signedDifference(_ lhs: UInt64, _ rhs: UInt64) -> Int64 {
        if lhs >= rhs { return Int64(clamping: lhs - rhs) }
        return -Int64(clamping: rhs - lhs)
    }
}
