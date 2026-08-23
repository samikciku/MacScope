import Foundation

enum ProcessLaunchArgumentsInspection: Equatable, Sendable {
    case loading
    case loaded([String], wasTruncated: Bool)
    case unavailable(String)
}
