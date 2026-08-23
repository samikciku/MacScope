import Darwin
import Foundation

/// Opt-in, read-only runtime audit for the App Store configuration.
///
/// Set `MACSCOPE_SANDBOX_AUDIT=1` before launching a sandboxed development
/// build. The report contains only capability states and aggregate counts.
actor AppStoreSandboxAudit {
    struct Result: Codable, Sendable {
        let capability: String
        let status: String
        let detail: String
    }

    struct Report: Codable, Sendable {
        let schemaVersion: Int
        let generatedAt: Date
        let sandboxed: Bool
        let results: [Result]
    }

    private static let shared = AppStoreSandboxAudit()
    private var hasRun = false

    static func runIfRequested() async {
        guard DistributionChannel.isMacAppStore,
              ProcessInfo.processInfo.environment["MACSCOPE_SANDBOX_AUDIT"] == "1" else { return }
        await shared.runOnce()
    }

    private func runOnce() async {
        guard !hasRun else { return }
        hasRun = true

        var results: [Result] = []
        await probe("cpu", into: &results) {
            let stats = try await CPUMonitor().currentStats()
            return "cores=\(stats.perCoreUsage.count)"
        }
        await probe("memory", into: &results) {
            let stats = try await MemoryMonitor().currentStats()
            switch stats.swap {
            case .available: return "host_statistics=available; swap=available"
            case .unavailable(let reason): return "host_statistics=available; swap=unavailable (\(reason))"
            case .unsupported(let reason): return "host_statistics=available; swap=unsupported (\(reason))"
            }
        }
        await probe("process_enumeration", into: &results) {
            let processes = try await ProcessMonitor().currentProcesses()
            guard !processes.isEmpty else { throw AuditError.emptyResult }
            return "visible_processes=\(processes.count)"
        }
        await probe("system_metadata", into: &results) {
            _ = try await SystemMonitor().currentInfo()
            return "available"
        }
        await probe("disk_capacity_and_io", into: &results) {
            let stats = try await DiskMonitor().currentStats()
            switch stats.ioActivity {
            case .available(let activity): return "capacity=available; io_devices=\(activity.deviceCount)"
            case .unavailable(let reason): return "capacity=available; io=unavailable (\(reason))"
            case .unsupported(let reason): return "capacity=available; io=unsupported (\(reason))"
            }
        }
        await probe("network_interfaces", into: &results) {
            let stats = try await NetworkMonitor().currentStats()
            return "interfaces=\(stats.interfaces.count)"
        }
        await probe("per_process_network", into: &results) {
            switch await ProcessNetworkMonitor().currentUsage() {
            case .available(let usage): return "visible_processes=\(usage.count)"
            case .unavailable(let reason): throw AuditError.unavailable(reason)
            case .unsupported(let reason): throw AuditError.unavailable(reason)
            }
        }
        await probe("metal_gpu", into: &results) {
            let stats = try await MetalGPUMonitor().currentStats()
            return "devices=\(stats.devices.count)"
        }
        await probe("own_process_arguments", into: &results) {
            let inspected = try await ProcessArgumentInspector().arguments(for: getpid())
            return "arguments=\(inspected.arguments.count)"
        }
        await probe("own_process_connections", into: &results) {
            let connections = try await ProcessConnectionInspector().connections(for: getpid())
            return "connections=\(connections.count)"
        }

        results.append(.init(
            capability: "user_selected_storage",
            status: "requires_user_action",
            detail: "Verify Open Panel access, recursive scan, and Trash manually."
        ))
        results.append(.init(
            capability: "process_termination",
            status: "not_tested",
            detail: "Destructive capability is excluded from the automated audit."
        ))
        results.append(.init(
            capability: "privileged_gpu_helper",
            status: "excluded",
            detail: "Disabled by the Mac App Store distribution policy."
        ))

        let report = Report(
            schemaVersion: 1,
            generatedAt: Date(),
            sandboxed: Self.isSandboxed,
            results: results
        )
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("MacScope", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder.auditEncoder.encode(report)
            try data.write(to: directory.appendingPathComponent("sandbox-capability-audit.json"), options: .atomic)
        } catch {
            NSLog("MacScope sandbox audit could not write its report: %@", error.localizedDescription)
        }
    }

    private func probe(
        _ capability: String,
        into results: inout [Result],
        operation: () async throws -> String
    ) async {
        do {
            results.append(.init(capability: capability, status: "available", detail: try await operation()))
        } catch {
            results.append(.init(capability: capability, status: "unavailable", detail: error.localizedDescription))
        }
    }

    private static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    private enum AuditError: LocalizedError {
        case emptyResult
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .emptyResult: "The API returned no visible records."
            case .unavailable(let reason): reason
            }
        }
    }
}

private extension JSONEncoder {
    static var auditEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
