import Foundation

struct ThermalStats: Equatable, Sendable {
    enum State: Int, CaseIterable, Equatable, Sendable {
        case nominal = 0
        case fair = 1
        case serious = 2
        case critical = 3

        var title: String {
            switch self {
            case .nominal: "Nominal"
            case .fair: "Fair"
            case .serious: "Serious"
            case .critical: "Critical"
            }
        }
    }

    let timestamp: Date
    let state: State
    let lowPowerModeEnabled: Bool
}
