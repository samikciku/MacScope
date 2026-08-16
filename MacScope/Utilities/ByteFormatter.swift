import Foundation

enum ByteFormatter {
    static func string(fromByteCount bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: clampedInt64(bytes))
    }

    private static func clampedInt64(_ value: UInt64) -> Int64 {
        value > UInt64(Int64.max) ? Int64.max : Int64(value)
    }
}
