import Darwin
import Foundation
import Testing
@testable import MacScope

struct ProcessMetadataResolverTests {
    @Test func mapsSupportedCPUArchitectures() {
        #expect(ProcessMetadataResolver.architectureName(cpuType: CPU_TYPE_ARM64) == "arm64")
        #expect(ProcessMetadataResolver.architectureName(cpuType: CPU_TYPE_X86_64) == "x86_64")
        #expect(ProcessMetadataResolver.architectureName(cpuType: cpu_type_t.max) == nil)
    }

    @Test func readsBundleIdentifierFromContainingApplication() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacScopeMetadata-\(UUID().uuidString).app")
        let contents = temporary.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("MacOS/Test")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.metadata-test",
            "CFBundleExecutable": "Test",
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        #expect(ProcessMetadataResolver.bundleIdentifier(executablePath: executable.path) == "com.example.metadata-test")
        #expect(ProcessMetadataResolver.bundleIdentifier(executablePath: "/usr/bin/true") == nil)
    }

    @Test func reportsMissingSigningTargetsWithoutInventingMetadata() {
        #expect(ProcessMetadataResolver.codeSigningInfo(executablePath: nil) == nil)

        let result = ProcessMetadataResolver.codeSigningInfo(
            executablePath: "/definitely/not/a/real/MacScope/executable"
        )
        #expect(result?.validation == .unavailable)
        #expect(result?.signingIdentifier == nil)
        #expect(result?.teamIdentifier == nil)
    }

    @Test func readsSigningMetadataForCurrentExecutable() {
        let result = ProcessMetadataResolver.codeSigningInfo(executablePath: CommandLine.arguments.first)

        #expect(result != nil)
        #expect(result?.validation != .unavailable)
        if result?.validation == .valid {
            #expect(result?.signingIdentifier?.isEmpty == false)
        }
    }
}
