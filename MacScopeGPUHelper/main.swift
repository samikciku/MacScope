import Foundation
import MacScopeHelperShared
import Darwin

private final class GPUHelperService: NSObject, MacScopeGPUHelperProtocol {
    func sampleGPU(reply: @escaping (Data?, String?) -> Void) {
        let process = Process()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacScope-GPUHelper-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        } catch {
            reply(nil, error.localizedDescription)
            return
        }
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let outputURL = temporaryDirectory.appendingPathComponent("stdout")
        let errorURL = temporaryDirectory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)

        process.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        process.arguments = [
            "--samplers", "gpu_power", "--sample-count", "1",
            "--sample-rate", "1000", "--format", "text"
        ]

        do {
            let output = try FileHandle(forWritingTo: outputURL)
            let errors = try FileHandle(forWritingTo: errorURL)
            defer { try? output.close(); try? errors.close() }
            process.standardOutput = output
            process.standardError = errors
            let completion = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in completion.signal() }
            try process.run()
            guard completion.wait(timeout: .now() + 5) == .success else {
                process.terminate()
                if completion.wait(timeout: .now() + 1) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                }
                reply(nil, "powermetrics GPU sampling timed out.")
                return
            }
            try output.synchronize()
            try errors.synchronize()
            let data = try Data(contentsOf: outputURL)
            let errorData = try Data(contentsOf: errorURL)
            guard process.terminationStatus == 0 else {
                let reason = String(decoding: errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                reply(nil, reason.isEmpty ? "powermetrics GPU sampling failed." : reason)
                return
            }
            guard data.count <= 1_048_576 else {
                reply(nil, "powermetrics output exceeded the safety limit.")
                return
            }
            let sample = PowermetricsGPUParser.parse(String(decoding: data, as: UTF8.self))
            reply(try JSONEncoder().encode(sample), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }

}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = GPUHelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: MacScopeGPUHelperProtocol.self)
        connection.exportedObject = service
        connection.activate()
        return true
    }
}

guard let clientRequirement = ProcessInfo.processInfo.environment["MACSCOPE_CLIENT_REQUIREMENT"],
      !clientRequirement.isEmpty else {
    FileHandle.standardError.write(Data("Missing client code-signing requirement.\n".utf8))
    exit(EXIT_FAILURE)
}
private let delegate = ListenerDelegate()
private let listener = NSXPCListener(machServiceName: macScopeGPUHelperMachService)
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = delegate
listener.activate()
RunLoop.current.run()
