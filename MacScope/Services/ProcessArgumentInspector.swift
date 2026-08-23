import Darwin
import Foundation

enum ProcessArgumentInspectorError: LocalizedError, Equatable, Sendable {
    case unavailable(Int32)
    case oversized
    case malformed

    var errorDescription: String? {
        switch self {
        case .unavailable(let code):
            "Launch arguments are unavailable (errno \(code))."
        case .oversized:
            "Launch arguments exceed MacScope's inspection limit."
        case .malformed:
            "Launch arguments could not be decoded safely."
        }
    }
}

actor ProcessArgumentInspector {
    private static let maximumRawBytes = 1_048_576
    static let maximumArguments = 64
    static let maximumArgumentCharacters = 256

    func arguments(for pid: Int32) throws -> (arguments: [String], wasTruncated: Bool) {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var requiredSize = 0
        guard sysctl(&mib, u_int(mib.count), nil, &requiredSize, nil, 0) == 0 else {
            throw ProcessArgumentInspectorError.unavailable(errno)
        }
        guard requiredSize > 0 else { throw ProcessArgumentInspectorError.malformed }
        guard requiredSize <= Self.maximumRawBytes else { throw ProcessArgumentInspectorError.oversized }

        var data = Data(count: requiredSize)
        var actualSize = requiredSize
        let status = data.withUnsafeMutableBytes { bytes in
            sysctl(&mib, u_int(mib.count), bytes.baseAddress, &actualSize, nil, 0)
        }
        guard status == 0 else { throw ProcessArgumentInspectorError.unavailable(errno) }
        data.count = actualSize

        let parsed = try Self.parse(data)
        let wasTruncated = parsed.count > Self.maximumArguments
            || parsed.contains { $0.count > Self.maximumArgumentCharacters }
        let bounded = parsed.prefix(Self.maximumArguments).map {
            String($0.prefix(Self.maximumArgumentCharacters))
        }
        return (Self.redact(bounded), wasTruncated)
    }

    static func parse(_ data: Data) throws -> [String] {
        guard data.count >= MemoryLayout<Int32>.size else {
            throw ProcessArgumentInspectorError.malformed
        }
        var argumentCount: Int32 = 0
        _ = withUnsafeMutableBytes(of: &argumentCount) { destination in
            data.copyBytes(to: destination, from: 0..<MemoryLayout<Int32>.size)
        }
        guard argumentCount >= 0, argumentCount <= 100_000 else {
            throw ProcessArgumentInspectorError.malformed
        }

        let bytes = [UInt8](data)
        var offset = MemoryLayout<Int32>.size
        while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
        while offset < bytes.count, bytes[offset] == 0 { offset += 1 }

        var arguments: [String] = []
        arguments.reserveCapacity(Swift.min(Int(argumentCount), maximumArguments + 1))
        for _ in 0..<Int(argumentCount) where offset < bytes.count {
            let start = offset
            while offset < bytes.count, bytes[offset] != 0 { offset += 1 }
            guard offset > start else { throw ProcessArgumentInspectorError.malformed }
            arguments.append(String(decoding: bytes[start..<offset], as: UTF8.self))
            while offset < bytes.count, bytes[offset] == 0 { offset += 1 }
        }
        guard arguments.count == Int(argumentCount) else {
            throw ProcessArgumentInspectorError.malformed
        }
        return arguments
    }

    static func redact<S: Sequence>(_ arguments: S) -> [String] where S.Element == String {
        var redactNext = false
        return arguments.map { argument in
            if redactNext {
                redactNext = false
                return "[REDACTED]"
            }

            if let equals = argument.firstIndex(of: "=") {
                let key = String(argument[..<equals])
                if isSensitiveName(key) {
                    return key + "=[REDACTED]"
                }
            }
            if isSensitiveName(argument) {
                redactNext = true
                return argument
            }
            if isRecognizedSecret(argument) { return "[REDACTED]" }
            return redactURLCredentials(argument)
        }
    }

    private static func isSensitiveName(_ value: String) -> Bool {
        let normalized = value.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .replacingOccurrences(of: "_", with: "-")
        let markers = [
            "password", "passwd", "passphrase", "secret", "token", "api-key",
            "authorization", "credential", "private-key", "access-key", "session-key",
            "client-secret"
        ]
        return markers.contains { normalized == $0 || normalized.hasSuffix("-\($0)") }
    }

    private static func isRecognizedSecret(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.hasPrefix("bearer ") || lower.hasPrefix("basic ") { return true }
        let prefixes = ["ghp_", "github_pat_", "xoxb-", "xoxp-", "sk-", "akia", "asia"]
        if prefixes.contains(where: lower.hasPrefix) { return true }

        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        return components.count == 3
            && components.allSatisfy { $0.count >= 8 && $0.allSatisfy(isBase64URLCharacter) }
    }

    private static func isBase64URLCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "_"
    }

    private static func redactURLCredentials(_ value: String) -> String {
        guard let schemeRange = value.range(of: "://"),
              let atIndex = value[schemeRange.upperBound...].firstIndex(of: "@"),
              let colonIndex = value[schemeRange.upperBound..<atIndex].firstIndex(of: ":") else {
            return value
        }
        return String(value[..<value.index(after: colonIndex)])
            + "[REDACTED]"
            + String(value[atIndex...])
    }
}
