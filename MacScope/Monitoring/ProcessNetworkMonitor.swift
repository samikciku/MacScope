import Foundation

actor ProcessNetworkMonitor {
    struct Counter: Equatable, Sendable {
        let pid: Int32
        let name: String
        let receivedBytes: UInt64
        let sentBytes: UInt64
    }

    private var previous: [Int32: Counter] = [:]
    private var previousTime: Date?

    func currentUsage() -> MetricAvailability<[ProcessNetworkUsage]> {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .unavailable(reason: "Could not start macOS nettop: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .unavailable(reason: detail?.isEmpty == false ? detail! : "macOS denied per-process network statistics.")
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return .unavailable(reason: "macOS returned unreadable per-process network statistics.")
        }

        let counters = Self.parse(text)
        let now = Date()
        let elapsed = previousTime.map { now.timeIntervalSince($0) }
        let usage = counters.map { counter in
            let old = previous[counter.pid]
            let download = rate(current: counter.receivedBytes, previous: old?.receivedBytes, elapsed: elapsed)
            let upload = rate(current: counter.sentBytes, previous: old?.sentBytes, elapsed: elapsed)
            return ProcessNetworkUsage(
                pid: counter.pid,
                name: counter.name,
                totalReceivedBytes: counter.receivedBytes,
                totalSentBytes: counter.sentBytes,
                downloadBytesPerSecond: download,
                uploadBytesPerSecond: upload
            )
        }
        previous = Dictionary(uniqueKeysWithValues: counters.map { ($0.pid, $0) })
        previousTime = now
        return .available(usage.sorted(by: Self.ranksBefore))
    }

    static func parse(_ text: String) -> [Counter] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let columns = line.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count >= 3,
                  let separator = columns[0].lastIndex(of: "."),
                  let pid = Int32(columns[0][columns[0].index(after: separator)...]),
                  let received = UInt64(columns[1]),
                  let sent = UInt64(columns[2]) else { return nil }
            return Counter(
                pid: pid,
                name: String(columns[0][..<separator]),
                receivedBytes: received,
                sentBytes: sent
            )
        }
    }

    private func rate(current: UInt64, previous: UInt64?, elapsed: TimeInterval?) -> Double? {
        guard let previous, let elapsed, elapsed > 0, current >= previous else { return nil }
        return Double(current - previous) / elapsed
    }

    private static func ranksBefore(_ lhs: ProcessNetworkUsage, _ rhs: ProcessNetworkUsage) -> Bool {
        let lhsRate = lhs.currentBytesPerSecond ?? 0
        let rhsRate = rhs.currentBytesPerSecond ?? 0
        if lhsRate != rhsRate { return lhsRate > rhsRate }
        return lhs.totalReceivedBytes + lhs.totalSentBytes > rhs.totalReceivedBytes + rhs.totalSentBytes
    }
}
