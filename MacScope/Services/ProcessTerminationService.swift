import Darwin
import Foundation

enum ProcessTerminationError: Error, Equatable, LocalizedError, Sendable {
    case denied(String)
    case alreadyExited
    case identityChanged
    case permissionDenied
    case signalFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .denied(let reason): reason
        case .alreadyExited: "The process has already exited."
        case .identityChanged: "The PID now belongs to a different process, so no signal was sent."
        case .permissionDenied: "macOS denied permission to terminate this process."
        case .signalFailed(let code): "The termination signal failed (errno \(code))."
        }
    }
}

enum ProcessTerminationSignal: Sendable {
    case terminate
    case kill

    var rawValue: Int32 {
        switch self {
        case .terminate: SIGTERM
        case .kill: SIGKILL
        }
    }
}

actor ProcessTerminationService {
    private let policy: ProcessTerminationPolicy

    init(policy: ProcessTerminationPolicy = ProcessTerminationPolicy()) {
        self.policy = policy
    }

    func send(_ signal: ProcessTerminationSignal, to process: ProcessSnapshot) throws {
        if case .denied(let reason) = policy.decision(for: process) {
            throw ProcessTerminationError.denied(reason)
        }
        guard let currentIdentity = identity(for: process.pid) else {
            throw ProcessTerminationError.alreadyExited
        }
        guard currentIdentity == process.identity else {
            throw ProcessTerminationError.identityChanged
        }

        guard kill(process.pid, signal.rawValue) == 0 else {
            switch errno {
            case ESRCH: throw ProcessTerminationError.alreadyExited
            case EPERM, EACCES: throw ProcessTerminationError.permissionDenied
            default: throw ProcessTerminationError.signalFailed(errno)
            }
        }
    }

    private func identity(for pid: pid_t) -> ProcessSnapshot.Identity? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let bytesRead = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, Int32(size))
        }
        guard bytesRead == size else { return nil }
        let startTime = Date(
            timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec)
                + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        )
        return ProcessSnapshot.Identity(pid: pid, startTime: startTime)
    }
}
