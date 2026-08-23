import AppKit
import Foundation

enum GroupTerminationMode: Equatable, Sendable {
    case quitApplication
    case terminateProcesses

    static func mode(for group: ApplicationProcessGroup) -> Self {
        group.applicationPath == nil ? .terminateProcesses : .quitApplication
    }
}

@MainActor
final class ApplicationQuitService {
    func requestQuit(processes: [ProcessSnapshot]) -> Int {
        let identifiers = Set(processes.map(\.pid))
        return identifiers.reduce(0) { count, pid in
            guard let application = NSRunningApplication(processIdentifier: pid) else { return count }
            return count + (application.terminate() ? 1 : 0)
        }
    }
}
