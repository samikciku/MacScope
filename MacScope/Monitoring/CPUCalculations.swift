struct CPUCoreTicks: Equatable, Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32
}

struct CPUUsageBreakdown: Equatable, Sendable {
    let total: Double
    let user: Double
    let system: Double
    let idle: Double
    let perCore: [Double]
}

enum CPUCalculations {
    static func usage(previous: [CPUCoreTicks], current: [CPUCoreTicks]) -> CPUUsageBreakdown? {
        guard !previous.isEmpty, previous.count == current.count else { return nil }

        var aggregateUser: UInt64 = 0
        var aggregateSystem: UInt64 = 0
        var aggregateIdle: UInt64 = 0
        var perCore: [Double] = []
        perCore.reserveCapacity(current.count)

        for (old, new) in zip(previous, current) {
            let user = UInt64(new.user &- old.user) + UInt64(new.nice &- old.nice)
            let system = UInt64(new.system &- old.system)
            let idle = UInt64(new.idle &- old.idle)
            let total = user + system + idle

            aggregateUser += user
            aggregateSystem += system
            aggregateIdle += idle
            perCore.append(total == 0 ? 0 : Double(user + system) / Double(total))
        }

        let aggregateTotal = aggregateUser + aggregateSystem + aggregateIdle
        guard aggregateTotal > 0 else {
            return CPUUsageBreakdown(total: 0, user: 0, system: 0, idle: 1, perCore: perCore)
        }

        return CPUUsageBreakdown(
            total: Double(aggregateUser + aggregateSystem) / Double(aggregateTotal),
            user: Double(aggregateUser) / Double(aggregateTotal),
            system: Double(aggregateSystem) / Double(aggregateTotal),
            idle: Double(aggregateIdle) / Double(aggregateTotal),
            perCore: perCore
        )
    }
}
