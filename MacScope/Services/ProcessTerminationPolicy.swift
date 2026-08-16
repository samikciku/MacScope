import Darwin

enum ProcessTerminationDecision: Equatable, Sendable {
    case allowed
    case denied(reason: String)
}

struct ProcessTerminationPolicy: Sendable {
    private let criticalProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "loginwindow",
        "windowserver"
    ]

    func decision(
        for process: ProcessSnapshot,
        currentProcessID: pid_t = getpid()
    ) -> ProcessTerminationDecision {
        if process.pid == currentProcessID {
            return .denied(reason: "MacScope cannot terminate itself.")
        }
        if process.pid <= 1 {
            return .denied(reason: "This is a critical system process.")
        }
        if criticalProcessNames.contains(process.name.lowercased()) {
            return .denied(reason: "This process is required by macOS.")
        }
        if process.owner == "root" || process.owner == "0" {
            return .denied(reason: "Root-owned processes cannot be terminated by MacScope.")
        }
        return .allowed
    }
}
