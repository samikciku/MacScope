import Darwin
import Foundation

enum NetworkMonitorError: Error, LocalizedError, Sendable {
    case interfaceEnumeration(Int32)

    var errorDescription: String? {
        switch self {
        case .interfaceEnumeration(let code):
            "Unable to enumerate network interfaces (errno \(code))."
        }
    }
}

struct NetworkCounterSnapshot: Equatable, Sendable {
    let timestamp: TimeInterval
    let receivedBytes: UInt64
    let transmittedBytes: UInt64
}

enum NetworkCalculations {
    static func rates(
        current: NetworkCounterSnapshot,
        previous: NetworkCounterSnapshot?
    ) -> (download: Double?, upload: Double?) {
        guard let previous,
              current.timestamp > previous.timestamp,
              current.receivedBytes >= previous.receivedBytes,
              current.transmittedBytes >= previous.transmittedBytes else {
            return (nil, nil)
        }
        let elapsed = current.timestamp - previous.timestamp
        return (
            Double(current.receivedBytes - previous.receivedBytes) / elapsed,
            Double(current.transmittedBytes - previous.transmittedBytes) / elapsed
        )
    }
}

actor NetworkMonitor: NetworkMonitorProtocol {
    private var previousSnapshot: NetworkCounterSnapshot?

    func currentStats() async throws -> NetworkStats {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0 else {
            throw NetworkMonitorError.interfaceEnumeration(errno)
        }
        defer { freeifaddrs(firstAddress) }

        var interfaces: [NetworkInterfaceStats] = []
        var cursor = firstAddress
        while let address = cursor?.pointee {
            defer { cursor = address.ifa_next }
            guard let socketAddress = address.ifa_addr,
                  Int32(socketAddress.pointee.sa_family) == AF_LINK,
                  address.ifa_flags & UInt32(IFF_UP) != 0,
                  address.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let dataPointer = address.ifa_data else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            interfaces.append(.init(
                name: String(cString: address.ifa_name),
                receivedBytes: UInt64(data.ifi_ibytes),
                transmittedBytes: UInt64(data.ifi_obytes)
            ))
        }
        interfaces.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let totalReceived = interfaces.reduce(UInt64(0)) { clampedAdd($0, $1.receivedBytes) }
        let totalTransmitted = interfaces.reduce(UInt64(0)) { clampedAdd($0, $1.transmittedBytes) }
        let timestamp = Date()
        let snapshot = NetworkCounterSnapshot(
            timestamp: timestamp.timeIntervalSinceReferenceDate,
            receivedBytes: totalReceived,
            transmittedBytes: totalTransmitted
        )
        let rates = NetworkCalculations.rates(current: snapshot, previous: previousSnapshot)
        previousSnapshot = snapshot
        return NetworkStats(
            timestamp: timestamp,
            totalReceivedBytes: totalReceived,
            totalTransmittedBytes: totalTransmitted,
            downloadBytesPerSecond: rates.download,
            uploadBytesPerSecond: rates.upload,
            interfaces: interfaces
        )
    }

    private func clampedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
