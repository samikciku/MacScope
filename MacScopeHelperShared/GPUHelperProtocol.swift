import Foundation

public let macScopeGPUHelperMachService = "com.macscope.GPUMetricsHelper"

@objc public protocol MacScopeGPUHelperProtocol {
    func sampleGPU(reply: @escaping (Data?, String?) -> Void)
}

public struct PrivilegedGPUSample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let utilization: Double?
    public let powerWatts: Double?
    public let frequencyMHz: Double?

    public init(timestamp: Date, utilization: Double?, powerWatts: Double?, frequencyMHz: Double?) {
        self.timestamp = timestamp
        self.utilization = utilization
        self.powerWatts = powerWatts
        self.frequencyMHz = frequencyMHz
    }
}

public enum PowermetricsGPUParser {
    public static func parse(_ text: String, timestamp: Date = Date()) -> PrivilegedGPUSample {
        PrivilegedGPUSample(
            timestamp: timestamp,
            utilization: metric(in: text, labels: ["GPU HW active residency", "GPU active residency"], divisor: 100),
            powerWatts: metric(in: text, labels: ["GPU Power"], divisor: 1_000),
            frequencyMHz: metric(in: text, labels: ["GPU HW active frequency", "GPU active frequency"], divisor: 1)
        )
    }

    private static func metric(in text: String, labels: [String], divisor: Double) -> Double? {
        for line in text.split(whereSeparator: \.isNewline) {
            guard labels.contains(where: { line.localizedCaseInsensitiveContains($0) }),
                  let colon = line.firstIndex(of: ":") else { continue }
            let valueText = line[line.index(after: colon)...]
                .drop(while: { $0.isWhitespace })
                .prefix(while: { $0.isNumber || $0 == "." })
            if let value = Double(valueText) { return value / divisor }
        }
        return nil
    }
}
