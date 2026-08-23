import Darwin
import Foundation

enum ProcessConnectionInspectorError: LocalizedError, Equatable, Sendable {
    case toolUnavailable
    case timedOut
    case inspectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolUnavailable:
            "The macOS connection-inspection tool is unavailable."
        case .timedOut:
            "Open-connection inspection timed out."
        case .inspectionFailed(let reason):
            reason.isEmpty ? "Open connections could not be inspected." : reason
        }
    }
}

actor ProcessConnectionInspector {
    static let toolPath = "/usr/sbin/lsof"
    private static let maximumResults = 200
    private static let maximumOutputBytes = 1_048_576

    func connections(for pid: Int32) throws -> [ProcessNetworkEndpoint] {
        guard FileManager.default.isExecutableFile(atPath: Self.toolPath) else {
            throw ProcessConnectionInspectorError.toolUnavailable
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacScope-connections-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let outputURL = temporaryDirectory.appendingPathComponent("stdout")
        let errorURL = temporaryDirectory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        let errors = try FileHandle(forWritingTo: errorURL)
        defer {
            try? output.close()
            try? errors.close()
        }

        let process = Process()
        let completion = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: Self.toolPath)
        process.arguments = ["-nP", "-a", "-p", String(pid), "-i", "-FfptnPT"]
        process.standardOutput = output
        process.standardError = errors
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            throw ProcessConnectionInspectorError.inspectionFailed(error.localizedDescription)
        }
        guard completion.wait(timeout: .now() + 5) == .success else {
            process.terminate()
            if completion.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = completion.wait(timeout: .now() + 1)
            }
            throw ProcessConnectionInspectorError.timedOut
        }
        try output.synchronize()
        try errors.synchronize()

        let outputData = try boundedData(at: outputURL)
        let errorData = try boundedData(at: errorURL)
        let text = String(decoding: outputData, as: UTF8.self)
        let parsed = Self.parse(text, limit: Self.maximumResults)
        if process.terminationStatus != 0, parsed.isEmpty {
            let reason = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if reason.isEmpty { return [] }
            throw ProcessConnectionInspectorError.inspectionFailed(reason)
        }
        return parsed
    }

    private func boundedData(at url: URL) throws -> Data {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return data.count <= Self.maximumOutputBytes ? data : Data(data.prefix(Self.maximumOutputBytes))
    }

    static func parse(_ output: String, limit: Int = maximumResults) -> [ProcessNetworkEndpoint] {
        guard limit > 0 else { return [] }
        struct Record {
            var descriptor = "—"
            var family = "Unknown"
            var protocolName: String?
            var endpoint: String?
            var state: String?
        }

        var records: [ProcessNetworkEndpoint] = []
        var current: Record?

        func appendCurrent() {
            guard records.count < limit, let record = current, let endpoint = record.endpoint else { return }
            records.append(.init(
                id: records.count,
                fileDescriptor: record.descriptor,
                addressFamily: record.family,
                protocolName: record.protocolName,
                endpoint: endpoint,
                state: record.state
            ))
        }

        for line in output.split(whereSeparator: { $0.isNewline }) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            switch field {
            case "f":
                appendCurrent()
                guard records.count < limit else { return records }
                current = Record(descriptor: value)
            case "t": current?.family = value
            case "P": current?.protocolName = value
            case "n": current?.endpoint = value
            case "T":
                if value.hasPrefix("ST=") { current?.state = String(value.dropFirst(3)) }
            default: break
            }
        }
        appendCurrent()
        return records
    }
}
