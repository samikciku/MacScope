import Foundation

struct ProcessNetworkEndpoint: Identifiable, Equatable, Sendable {
    let id: Int
    let fileDescriptor: String
    let addressFamily: String
    let protocolName: String?
    let endpoint: String
    let state: String?

    var accessibilitySummary: String {
        "\(protocolName ?? addressFamily) connection, \(endpoint), \(state ?? "descriptor \(fileDescriptor)")"
    }
}

enum ProcessConnectionInspection: Equatable, Sendable {
    case loading
    case loaded([ProcessNetworkEndpoint])
    case unavailable(String)
}
