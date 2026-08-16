import Darwin
import Foundation

struct SystemMonitor: SystemMonitorProtocol {
    func currentInfo() async throws -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        let architecture = sysctlString("hw.machine") ?? "Unavailable"
        return SystemInfo(
            modelName: sysctlString("hw.model") ?? "Unavailable",
            processorName: sysctlString("machdep.cpu.brand_string") ?? architecture,
            physicalMemoryBytes: processInfo.physicalMemory,
            operatingSystemVersion: processInfo.operatingSystemVersionString,
            architecture: architecture,
            uptimeSeconds: processInfo.systemUptime,
            logicalCoreCount: processInfo.processorCount
        )
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let content = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let value = String(decoding: content, as: UTF8.self)
        return value.isEmpty ? nil : value
    }
}
