import Foundation

struct BatteryStats: Equatable, Sendable {
    enum PowerSource: String, Equatable, Sendable {
        case ac = "AC Power"
        case battery = "Battery Power"
        case unknown = "Unknown"
    }

    let timestamp: Date
    let name: String
    let chargeFraction: Double
    let isCharging: Bool
    let powerSource: PowerSource
    let timeRemainingMinutes: Int?
    let timeToFullMinutes: Int?
    let health: String?
    let maximumCapacity: Int
    let designCapacity: Int?
    let adapterWatts: Int?

    var healthFraction: Double? {
        guard let designCapacity, designCapacity > 0 else { return nil }
        return Swift.min(1, Double(maximumCapacity) / Double(designCapacity))
    }
}
