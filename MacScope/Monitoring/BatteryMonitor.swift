import Foundation
import IOKit.ps

struct BatteryMonitor: BatteryMonitorProtocol {
    func currentStats() async -> MetricAvailability<BatteryStats> {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unavailable(reason: "Unable to read the IOKit power-source snapshot.")
        }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unavailable(reason: "Unable to enumerate IOKit power sources.")
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description["Type"] as? String == "InternalBattery" else { continue }
            return parse(description)
        }
        return .unsupported(reason: "This Mac does not report an internal battery.")
    }

    private func parse(_ values: [String: Any]) -> MetricAvailability<BatteryStats> {
        guard let current = (values["Current Capacity"] as? NSNumber)?.doubleValue,
              let maximum = (values["Max Capacity"] as? NSNumber)?.doubleValue,
              maximum > 0 else {
            return .unavailable(reason: "The internal battery did not provide valid capacity values.")
        }
        let state = values["Power Source State"] as? String
        let powerSource: BatteryStats.PowerSource = switch state {
        case "AC Power": .ac
        case "Battery Power": .battery
        default: .unknown
        }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        return .available(BatteryStats(
            timestamp: Date(),
            name: values["Name"] as? String ?? "Internal Battery",
            chargeFraction: Swift.min(1, Swift.max(0, current / maximum)),
            isCharging: (values["Is Charging"] as? NSNumber)?.boolValue ?? false,
            powerSource: powerSource,
            timeRemainingMinutes: nonnegativeInteger(values["Time to Empty"]),
            timeToFullMinutes: nonnegativeInteger(values["Time to Full Charge"]),
            health: values["BatteryHealth"] as? String,
            maximumCapacity: Int(maximum),
            designCapacity: nonnegativeInteger(values["DesignCapacity"]),
            adapterWatts: nonnegativeInteger(adapter?["Watts"])
        ))
    }

    private func nonnegativeInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, number.intValue >= 0 else { return nil }
        return number.intValue
    }
}
