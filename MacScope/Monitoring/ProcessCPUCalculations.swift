import Foundation

enum ProcessCPUCalculations {
    /// Returns macOS-style CPU percentage where one fully occupied core is 100%.
    static func percent(
        previousNanoseconds: UInt64,
        currentNanoseconds: UInt64,
        elapsedSeconds: TimeInterval
    ) -> Double? {
        guard currentNanoseconds >= previousNanoseconds, elapsedSeconds > 0 else { return nil }
        let cpuDelta = currentNanoseconds - previousNanoseconds
        return Double(cpuDelta) / (elapsedSeconds * 1_000_000_000) * 100
    }
}

struct ProcessCumulativeResources: Equatable, Sendable {
    let wakeups: UInt64
    let diskReadBytes: UInt64
    let diskWriteBytes: UInt64
    let energyNanojoules: UInt64
}

struct ProcessResourceRates: Equatable, Sendable {
    let wakeupsPerSecond: Double
    let diskReadBytesPerSecond: Double
    let diskWriteBytesPerSecond: Double
    let powerWatts: Double
}

enum ProcessResourceCalculations {
    static func rates(
        previous: ProcessCumulativeResources,
        current: ProcessCumulativeResources,
        elapsedSeconds: TimeInterval
    ) -> ProcessResourceRates? {
        guard elapsedSeconds > 0,
              current.wakeups >= previous.wakeups,
              current.diskReadBytes >= previous.diskReadBytes,
              current.diskWriteBytes >= previous.diskWriteBytes,
              current.energyNanojoules >= previous.energyNanojoules else { return nil }
        return .init(
            wakeupsPerSecond: Double(current.wakeups - previous.wakeups) / elapsedSeconds,
            diskReadBytesPerSecond: Double(current.diskReadBytes - previous.diskReadBytes) / elapsedSeconds,
            diskWriteBytesPerSecond: Double(current.diskWriteBytes - previous.diskWriteBytes) / elapsedSeconds,
            powerWatts: Double(current.energyNanojoules - previous.energyNanojoules) / elapsedSeconds / 1_000_000_000
        )
    }
}
