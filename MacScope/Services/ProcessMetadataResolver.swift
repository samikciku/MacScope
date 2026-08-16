import Darwin
import Foundation

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
}
