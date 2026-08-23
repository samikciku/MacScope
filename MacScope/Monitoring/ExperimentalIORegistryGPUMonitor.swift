import Foundation

struct ExperimentalIORegistryGPUMonitor: GPUMonitorProtocol {
    enum MonitorError: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): reason
            }
        }
    }

    func currentStats() async throws -> GPUStats {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AGXAccelerator", "-l", "-w", "0"]
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let reason = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw MonitorError.unavailable(reason.isEmpty ? "IORegistry GPU data is unavailable." : reason)
        }
        guard data.count <= 4_194_304 else {
            throw MonitorError.unavailable("IORegistry GPU output exceeded the safety limit.")
        }
        let text = String(decoding: data, as: UTF8.self)
        guard text.contains("AGXAccelerator"), text.contains("PerformanceStatistics") else {
            throw MonitorError.unavailable("This Mac did not expose compatible AGX performance statistics.")
        }

        let metal = try await MetalGPUMonitor().currentStats()
        return GPUStats(
            timestamp: Date(),
            utilization: percent(Self.number(named: "Device Utilization %", in: text)),
            devices: metal.devices,
            sourceDescription: "Experimental source: undocumented AGX IORegistry performance statistics. Field names may change with macOS updates.",
            rendererUtilization: optionalPercent(Self.number(named: "Renderer Utilization %", in: text)),
            tilerUtilization: optionalPercent(Self.number(named: "Tiler Utilization %", in: text)),
            allocatedMemoryBytes: unsigned(Self.number(named: "Alloc system memory", in: text)),
            inUseMemoryBytes: unsigned(Self.number(named: "In use system memory", in: text)),
            coreCount: integer(Self.number(named: "gpu-core-count", in: text))
        )
    }

    static func number(named key: String, in text: String) -> NSNumber? {
        guard let keyRange = text.range(of: "\"\(key)\"=") else { return nil }
        let value = text[keyRange.upperBound...]
            .drop(while: { $0.isWhitespace })
            .prefix(while: { $0.isNumber || $0 == "." })
        guard let number = Double(value) else { return nil }
        return NSNumber(value: number)
    }

    private func percent(_ value: NSNumber?) -> MetricAvailability<Double> {
        guard let value = optionalPercent(value) else {
            return .unavailable(reason: "AGX did not publish Device Utilization % on this Mac.")
        }
        return .available(value)
    }

    private func optionalPercent(_ number: NSNumber?) -> Double? {
        guard let number else { return nil }
        return Swift.min(1, Swift.max(0, number.doubleValue / 100))
    }

    private func unsigned(_ value: NSNumber?) -> UInt64? {
        value?.uint64Value
    }

    private func integer(_ value: NSNumber?) -> Int? {
        value?.intValue
    }
}
