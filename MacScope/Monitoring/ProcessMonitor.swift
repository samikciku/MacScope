import Darwin
import Foundation

enum ProcessMonitorError: Error, Equatable, LocalizedError, Sendable {
    case enumerationFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .enumerationFailed(let code):
            "Unable to enumerate processes (errno \(code))."
        }
    }
}

actor ProcessMonitor: ProcessMonitorProtocol {
    private struct PreviousSample: Sendable {
        let cpuNanoseconds: UInt64
        let timestamp: Date
        let resources: ProcessCumulativeResources?
    }

    private struct StaticMetadata: Sendable {
        let name: String
        let path: String?
        let owner: String?
        let architecture: String?
        let bundleIdentifier: String?
    }

    private var previousSamples: [ProcessSnapshot.Identity: PreviousSample] = [:]
    private var metadataCache: [ProcessSnapshot.Identity: StaticMetadata] = [:]
    private var ownerCache: [uid_t: String] = [:]

    func currentProcesses() async throws -> [ProcessSnapshot] {
        let timestamp = Date()
        let pids = try listAllPIDs()
        var snapshots: [ProcessSnapshot] = []
        var nextPrevious: [ProcessSnapshot.Identity: PreviousSample] = [:]
        var activeIdentities = Set<ProcessSnapshot.Identity>()
        snapshots.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            guard let bsdInfo = readBSDInfo(pid: pid),
                  let taskInfo = readTaskInfo(pid: pid) else {
                continue
            }

            let identity = ProcessSnapshot.Identity(
                pid: pid,
                startTime: processStartDate(from: bsdInfo)
            )
            let cpuNanoseconds = taskInfo.pti_total_user &+ taskInfo.pti_total_system
            let resources = readResourceUsage(pid: pid)
            let cpuPercent: Double
            if let previous = previousSamples[identity] {
                cpuPercent = ProcessCPUCalculations.percent(
                    previousNanoseconds: previous.cpuNanoseconds,
                    currentNanoseconds: cpuNanoseconds,
                    elapsedSeconds: timestamp.timeIntervalSince(previous.timestamp)
                ) ?? 0
            } else {
                cpuPercent = 0
            }
            let resourceRates: ProcessResourceRates? = previousSamples[identity].flatMap { previous in
                guard let previousResources = previous.resources, let resources else { return nil }
                return ProcessResourceCalculations.rates(
                    previous: previousResources,
                    current: resources,
                    elapsedSeconds: timestamp.timeIntervalSince(previous.timestamp)
                )
            }

            let metadata = metadataCache[identity] ?? readMetadata(pid: pid, uid: bsdInfo.pbi_uid)
            metadataCache[identity] = metadata
            activeIdentities.insert(identity)
            nextPrevious[identity] = PreviousSample(cpuNanoseconds: cpuNanoseconds, timestamp: timestamp, resources: resources)

            snapshots.append(
                ProcessSnapshot(
                    identity: identity,
                    parentPID: Int32(bitPattern: bsdInfo.pbi_ppid),
                    name: metadata.name,
                    executablePath: metadata.path,
                    residentBytes: taskInfo.pti_resident_size,
                    virtualBytes: taskInfo.pti_virtual_size,
                    cpuPercent: cpuPercent,
                    threadCount: Swift.max(0, Int(taskInfo.pti_threadnum)),
                    owner: metadata.owner,
                    architecture: metadata.architecture,
                    bundleIdentifier: metadata.bundleIdentifier,
                    timestamp: timestamp,
                    wakeupsPerSecond: resourceRates?.wakeupsPerSecond,
                    diskReadBytesPerSecond: resourceRates?.diskReadBytesPerSecond,
                    diskWriteBytesPerSecond: resourceRates?.diskWriteBytesPerSecond,
                    energyNanojoules: resources?.energyNanojoules,
                    estimatedPowerWatts: resourceRates?.powerWatts
                )
            )
        }

        previousSamples = nextPrevious
        metadataCache = metadataCache.filter { activeIdentities.contains($0.key) }
        return snapshots
    }

    private func listAllPIDs() throws -> [pid_t] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount >= 0 else {
            throw ProcessMonitorError.enumerationFailed(errno)
        }

        var pids = [pid_t](repeating: 0, count: Swift.max(Int(estimatedCount) + 64, 128))
        let actualCount = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard actualCount >= 0 else {
            throw ProcessMonitorError.enumerationFailed(errno)
        }
        return Array(pids.prefix(Int(actualCount)))
    }

    private func readBSDInfo(pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let bytesRead = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, Int32(size))
        }
        return bytesRead == size ? info : nil
    }

    private func readTaskInfo(pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let bytesRead = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, Int32(size))
        }
        return bytesRead == size ? info : nil
    }

    private func readResourceUsage(pid: pid_t) -> ProcessCumulativeResources? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            let buffer = UnsafeMutableRawPointer(pointer)
                .assumingMemoryBound(to: Optional<UnsafeMutableRawPointer>.self)
            return proc_pid_rusage(pid, RUSAGE_INFO_V6, buffer)
        }
        guard result == 0 else { return nil }
        return .init(
            wakeups: info.ri_pkg_idle_wkups &+ info.ri_interrupt_wkups,
            diskReadBytes: info.ri_diskio_bytesread,
            diskWriteBytes: info.ri_diskio_byteswritten,
            energyNanojoules: info.ri_energy_nj
        )
    }

    private func processStartDate(from info: proc_bsdinfo) -> Date {
        let seconds = TimeInterval(info.pbi_start_tvsec)
        let microseconds = TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return Date(timeIntervalSince1970: seconds + microseconds)
    }

    private func readMetadata(pid: pid_t, uid: uid_t) -> StaticMetadata {
        let path = readPath(pid: pid)
        let name = readName(pid: pid)
            ?? path.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? "PID \(pid)"
        return StaticMetadata(
            name: name,
            path: path,
            owner: ownerName(for: uid),
            architecture: readArchitecture(pid: pid),
            bundleIdentifier: ProcessMetadataResolver.bundleIdentifier(executablePath: path)
        )
    }

    private func readArchitecture(pid: pid_t) -> String? {
        var info = proc_archinfo()
        let size = MemoryLayout<proc_archinfo>.size
        let bytesRead = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDARCHINFO, 0, $0, Int32(size))
        }
        guard bytesRead == size else { return nil }
        return ProcessMetadataResolver.architectureName(cpuType: info.p_cputype)
    }

    private func readName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return decode(buffer, length: length)
    }

    private func readPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return decode(buffer, length: length)
    }

    private func decode(_ buffer: [CChar], length: Int32) -> String? {
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func ownerName(for uid: uid_t) -> String {
        if let cached = ownerCache[uid] { return cached }

        var password = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 4_096)
        let status = getpwuid_r(uid, &password, &buffer, buffer.count, &result)
        let name: String
        if status == 0, result != nil, let pointer = password.pw_name {
            name = String(cString: pointer)
        } else {
            name = String(uid)
        }
        ownerCache[uid] = name
        return name
    }
}
