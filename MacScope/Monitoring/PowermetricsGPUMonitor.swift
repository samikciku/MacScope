import Foundation
import MacScopeHelperShared

struct PowermetricsGPUMonitor: GPUMonitorProtocol {
    enum MonitorError: LocalizedError {
        case unavailable(String)
        var errorDescription: String? {
            switch self { case .unavailable(let reason): reason }
        }
    }

    func currentStats() async throws -> GPUStats {
        let sample = try await sampleFromHelper()
        let metal = try await MetalGPUMonitor().currentStats()
        let utilization: MetricAvailability<Double> = sample.utilization.map(MetricAvailability.available)
            ?? .unavailable(reason: "powermetrics did not publish GPU active residency on this Mac.")
        return GPUStats(
            timestamp: sample.timestamp,
            utilization: utilization,
            devices: metal.devices,
            sourceDescription: "Privileged source: Apple powermetrics via MacScope’s allowlisted read-only helper.",
            powerWatts: sample.powerWatts,
            frequencyMHz: sample.frequencyMHz
        )
    }

    private func sampleFromHelper() async throws -> PrivilegedGPUSample {
        try await withCheckedThrowingContinuation { continuation in
            let gate = SampleContinuationGate()
            let connection = NSXPCConnection(
                machServiceName: macScopeGPUHelperMachService,
                options: .privileged
            )
            connection.remoteObjectInterface = NSXPCInterface(with: MacScopeGPUHelperProtocol.self)
            connection.invalidationHandler = {
                gate.finish(
                    .failure(MonitorError.unavailable("The GPU helper connection was invalidated.")),
                    continuation: continuation
                )
            }
            connection.activate()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                connection.invalidationHandler = nil
                connection.invalidate()
                gate.finish(
                    .failure(MonitorError.unavailable(error.localizedDescription)),
                    continuation: continuation
                )
            }) as? MacScopeGPUHelperProtocol else {
                connection.invalidate()
                gate.finish(
                    .failure(MonitorError.unavailable("The GPU helper is not available.")),
                    continuation: continuation
                )
                return
            }
            proxy.sampleGPU { data, errorMessage in
                connection.invalidationHandler = nil
                connection.invalidate()
                do {
                    guard let data else {
                        throw MonitorError.unavailable(errorMessage ?? "The GPU helper returned no data.")
                    }
                    gate.finish(
                        .success(try JSONDecoder().decode(PrivilegedGPUSample.self, from: data)),
                        continuation: continuation
                    )
                } catch {
                    gate.finish(.failure(error), continuation: continuation)
                }
            }
        }
    }
}

private final class SampleContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func finish(
        _ result: Result<PrivilegedGPUSample, Error>,
        continuation: CheckedContinuation<PrivilegedGPUSample, Error>
    ) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        continuation.resume(with: result)
    }
}
