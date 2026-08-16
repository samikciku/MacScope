import Foundation
import Testing
@testable import MacScope

struct ProcessConnectionInspectorTests {
    @Test func parsesMachineReadableSocketRecords() {
        let output = """
        p42
        f12u
        tIPv4
        PTCP
        n127.0.0.1:8080->127.0.0.1:55000
        TST=ESTABLISHED
        f15u
        tIPv6
        PTCP
        n*:443
        TST=LISTEN
        """

        let connections = ProcessConnectionInspector.parse(output)

        #expect(connections.count == 2)
        #expect(connections[0].fileDescriptor == "12u")
        #expect(connections[0].protocolName == "TCP")
        #expect(connections[0].state == "ESTABLISHED")
        #expect(connections[1].endpoint == "*:443")
        #expect(connections[1].addressFamily == "IPv6")
        #expect(connections[1].accessibilitySummary == "TCP connection, *:443, LISTEN")
    }

    @Test func ignoresIncompleteRecordsAndHonorsResultLimit() {
        let output = """
        f1u
        tIPv4
        f2u
        tIPv4
        PUDP
        n*:53
        f3u
        tIPv4
        PTCP
        n*:80
        """

        let connections = ProcessConnectionInspector.parse(output, limit: 1)

        #expect(connections.count == 1)
        #expect(connections[0].endpoint == "*:53")
    }

    @Test func inspectsCurrentProcessOrReportsAnExplicitUnavailableState() async {
        let inspector = ProcessConnectionInspector()
        do {
            let connections = try await inspector.connections(for: Int32(ProcessInfo.processInfo.processIdentifier))
            #expect(connections.count <= 200)
            #expect(connections.allSatisfy { !$0.endpoint.isEmpty })
        } catch {
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}
