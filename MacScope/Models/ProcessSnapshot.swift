import Foundation

struct ProcessSnapshot: Identifiable, Equatable, Sendable {
    struct Identity: Hashable, Sendable {
        let pid: Int32
        let startTime: Date?
    }

    let identity: Identity
    let parentPID: Int32?
    let name: String
    let executablePath: String?
    let residentBytes: UInt64
    let virtualBytes: UInt64?
    let cpuPercent: Double
    let threadCount: Int
    let owner: String?
    let architecture: String?
    let bundleIdentifier: String?
    let timestamp: Date
    let wakeupsPerSecond: Double?
    let diskReadBytesPerSecond: Double?
    let diskWriteBytesPerSecond: Double?
    let energyNanojoules: UInt64?
    let estimatedPowerWatts: Double?

    init(
        identity: Identity,
        parentPID: Int32?,
        name: String,
        executablePath: String?,
        residentBytes: UInt64,
        virtualBytes: UInt64?,
        cpuPercent: Double,
        threadCount: Int,
        owner: String?,
        architecture: String?,
        bundleIdentifier: String? = nil,
        timestamp: Date,
        wakeupsPerSecond: Double? = nil,
        diskReadBytesPerSecond: Double? = nil,
        diskWriteBytesPerSecond: Double? = nil,
        energyNanojoules: UInt64? = nil,
        estimatedPowerWatts: Double? = nil
    ) {
        self.identity = identity
        self.parentPID = parentPID
        self.name = name
        self.executablePath = executablePath
        self.residentBytes = residentBytes
        self.virtualBytes = virtualBytes
        self.cpuPercent = cpuPercent
        self.threadCount = threadCount
        self.owner = owner
        self.architecture = architecture
        self.bundleIdentifier = bundleIdentifier
        self.timestamp = timestamp
        self.wakeupsPerSecond = wakeupsPerSecond
        self.diskReadBytesPerSecond = diskReadBytesPerSecond
        self.diskWriteBytesPerSecond = diskWriteBytesPerSecond
        self.energyNanojoules = energyNanojoules
        self.estimatedPowerWatts = estimatedPowerWatts
    }

    var id: Identity { identity }
    var pid: Int32 { identity.pid }
}
