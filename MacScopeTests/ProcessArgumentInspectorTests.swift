import Foundation
import Testing
@testable import MacScope

struct ProcessArgumentInspectorTests {
    @Test func parsesNativeProcargsLayoutAndHonorsArgumentCount() throws {
        let data = encoded(arguments: ["/usr/bin/tool", "--mode", "safe"], environment: ["TOKEN=must-not-parse"])

        let arguments = try ProcessArgumentInspector.parse(data)

        #expect(arguments == ["/usr/bin/tool", "--mode", "safe"])
    }

    @Test func rejectsTruncatedArgumentData() {
        let data = encoded(arguments: ["tool", "second"], declaredCount: 3)

        #expect(throws: ProcessArgumentInspectorError.malformed) {
            try ProcessArgumentInspector.parse(data)
        }
    }

    @Test func redactsNamedSecretsKnownTokensJWTsAndURLPasswords() {
        let arguments = [
            "tool", "--token", "plain-token", "API_KEY=abc123", "--client-secret=value",
            "Bearer abc.def", "ghp_abcdefghijklmnopqrstuvwxyz", "aaaabbbb.ccccdddd.eeeeffff",
            "https://user:password@example.com/path", "--mode=safe"
        ]

        let redacted = ProcessArgumentInspector.redact(arguments)

        #expect(redacted == [
            "tool", "--token", "[REDACTED]", "API_KEY=[REDACTED]", "--client-secret=[REDACTED]",
            "[REDACTED]", "[REDACTED]", "[REDACTED]",
            "https://user:[REDACTED]@example.com/path", "--mode=safe"
        ])
    }

    @Test func readsAndRedactsCurrentProcessArguments() async throws {
        let inspector = ProcessArgumentInspector()
        let result = try await inspector.arguments(for: Int32(ProcessInfo.processInfo.processIdentifier))

        #expect(!result.arguments.isEmpty)
        #expect(result.arguments.count <= ProcessArgumentInspector.maximumArguments)
        #expect(result.arguments.allSatisfy { $0.count <= ProcessArgumentInspector.maximumArgumentCharacters })
    }

    private func encoded(
        arguments: [String],
        declaredCount: Int32? = nil,
        environment: [String] = []
    ) -> Data {
        var data = Data()
        var count = declaredCount ?? Int32(arguments.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        data.append(contentsOf: "/usr/bin/tool".utf8)
        data.append(0)
        data.append(0)
        for value in arguments + environment {
            data.append(contentsOf: value.utf8)
            data.append(0)
        }
        return data
    }
}
