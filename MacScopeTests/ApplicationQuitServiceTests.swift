import Foundation
import Testing
@testable import MacScope

struct ApplicationQuitServiceTests {
    @Test func applicationGroupsPreferNormalQuit() {
        #expect(GroupTerminationMode.mode(for: group(path: "/Applications/Browser.app")) == .quitApplication)
    }

    @Test func commandLineGroupsUseProcessTermination() {
        #expect(GroupTerminationMode.mode(for: group(path: nil)) == .terminateProcesses)
    }

    private func group(path: String?) -> ApplicationProcessGroup {
        .init(id: "test", name: "Test", applicationPath: path, processes: [], residentBytes: 0, cpuPercent: 0, threadCount: 0)
    }
}
