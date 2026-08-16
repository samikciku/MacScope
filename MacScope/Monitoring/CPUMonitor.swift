import Darwin
import Foundation

enum CPUMonitorError: Error, Equatable, LocalizedError, Sendable {
    case processorInfo(kern_return_t)
    case invalidProcessorData

    var errorDescription: String? {
        switch self {
        case .processorInfo(let code):
            "Unable to read processor statistics (Mach error \(code))."
        case .invalidProcessorData:
            "The processor statistics returned by macOS were incomplete."
        }
    }
}

actor CPUMonitor: CPUMonitorProtocol {
    private var previousTicks: [CPUCoreTicks]?

    func currentStats() async throws -> CPUStats {
        let previous: [CPUCoreTicks]
        if let previousTicks {
            previous = previousTicks
        } else {
            previous = try readTicks()
            try await Task.sleep(for: .milliseconds(100))
        }

        let current = try readTicks()
        previousTicks = current
        guard let usage = CPUCalculations.usage(previous: previous, current: current) else {
            throw CPUMonitorError.invalidProcessorData
        }

        return CPUStats(
            timestamp: Date(),
            totalUsage: usage.total,
            userUsage: usage.user,
            systemUsage: usage.system,
            idleUsage: usage.idle,
            perCoreUsage: usage.perCore
        )
    }

    private func readTicks() throws -> [CPUCoreTicks] {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS else {
            throw CPUMonitorError.processorInfo(result)
        }
        guard let info else {
            throw CPUMonitorError.invalidProcessorData
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let statesPerCore = Int(CPU_STATE_MAX)
        guard infoCount >= processorCount * natural_t(statesPerCore) else {
            throw CPUMonitorError.invalidProcessorData
        }

        return (0..<Int(processorCount)).map { core in
            let offset = core * statesPerCore
            return CPUCoreTicks(
                user: UInt32(bitPattern: info[offset + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[offset + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[offset + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[offset + Int(CPU_STATE_NICE)])
            )
        }
    }
}
