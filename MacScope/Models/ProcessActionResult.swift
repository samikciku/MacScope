import Foundation

struct ProcessActionResult: Equatable, Identifiable, Sendable {
    enum Action: String, Sendable {
        case quitApplication = "Quit application"
        case terminateProcess = "End process"
        case terminateGroup = "End process group"
        case forceQuit = "Force quit"
    }

    enum Outcome: String, Sendable {
        case completed = "Completed"
        case stillRunning = "Still running"
        case noAction = "No action"
        case failed = "Failed"
    }

    let id: UUID
    let timestamp: Date
    let target: String
    let action: Action
    let outcome: Outcome
    let message: String

    init(target: String, action: Action, outcome: Outcome, message: String) {
        id = UUID()
        timestamp = Date()
        self.target = target
        self.action = action
        self.outcome = outcome
        self.message = message
    }
}
