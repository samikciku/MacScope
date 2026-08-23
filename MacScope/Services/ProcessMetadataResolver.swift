import Darwin
import Foundation
import Security

enum ProcessMetadataResolver {
    static func bundleIdentifier(executablePath: String?) -> String? {
        guard let applicationPath = ProcessGrouping.applicationPath(for: executablePath) else { return nil }
        return Bundle(path: applicationPath)?.bundleIdentifier
    }

    static func architectureName(cpuType: cpu_type_t) -> String? {
        switch cpuType {
        case CPU_TYPE_ARM64: "arm64"
        case CPU_TYPE_ARM64_32: "arm64_32"
        case CPU_TYPE_ARM: "arm"
        case CPU_TYPE_X86_64: "x86_64"
        case CPU_TYPE_X86: "i386"
        default: nil
        }
    }

    static func codeSigningInfo(executablePath: String?) -> ProcessCodeSigningInfo? {
        guard let executablePath, !executablePath.isEmpty else { return nil }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: executablePath) as CFURL,
            SecCSFlags(),
            &staticCode
        )
        guard createStatus == errSecSuccess, let staticCode else {
            return ProcessCodeSigningInfo(
                validation: createStatus == errSecCSUnsigned ? .unsigned : .unavailable,
                signingIdentifier: nil,
                teamIdentifier: nil
            )
        }

        var rawInformation: CFDictionary?
        let informationStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &rawInformation
        )
        guard informationStatus == errSecSuccess, let information = rawInformation as? [CFString: Any] else {
            return ProcessCodeSigningInfo(
                validation: informationStatus == errSecCSUnsigned ? .unsigned : .unavailable,
                signingIdentifier: nil,
                teamIdentifier: nil
            )
        }

        let validation: ProcessCodeSigningInfo.Validation =
            SecStaticCodeCheckValidity(staticCode, SecCSFlags(), nil) == errSecSuccess ? .valid : .invalid
        return ProcessCodeSigningInfo(
            validation: validation,
            signingIdentifier: information[kSecCodeInfoIdentifier] as? String,
            teamIdentifier: information[kSecCodeInfoTeamIdentifier] as? String
        )
    }
}

actor ProcessCodeSigningInspector {
    static let shared = ProcessCodeSigningInspector()
    private static let maximumCachedPaths = 256
    private var cache: [String: ProcessCodeSigningInfo] = [:]

    func information(executablePath: String?) -> ProcessCodeSigningInfo? {
        guard let executablePath, !executablePath.isEmpty else { return nil }
        if let cached = cache[executablePath] { return cached }

        guard let information = ProcessMetadataResolver.codeSigningInfo(executablePath: executablePath) else {
            return nil
        }
        if cache.count >= Self.maximumCachedPaths, let oldestKey = cache.keys.first {
            cache.removeValue(forKey: oldestKey)
        }
        cache[executablePath] = information
        return information
    }
}
