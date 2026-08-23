import Foundation

enum ResourceHogAnalyzer {
    static func findings(
        groups: [ApplicationProcessGroup],
        processNetworkUsage: [ProcessNetworkUsage],
        thresholds: ResourceHogThresholds
    ) -> [ResourceHogFinding] {
        measurements(
            groups: groups,
            processNetworkUsage: processNetworkUsage,
            thresholds: thresholds
        )
        .filter { $0.value >= $0.threshold }
        .map(\.finding)
        .sorted {
            if $0.thresholdMultiple != $1.thresholdMultiple { return $0.thresholdMultiple > $1.thresholdMultiple }
            if $0.applicationName != $1.applicationName {
                return $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending
            }
            return $0.category.rawValue < $1.category.rawValue
        }
    }

    static func measurements(
        groups: [ApplicationProcessGroup],
        processNetworkUsage: [ProcessNetworkUsage],
        thresholds: ResourceHogThresholds
    ) -> [ResourceHogMeasurement] {
        let networkByPID = Dictionary(uniqueKeysWithValues: processNetworkUsage.compactMap { usage in
            usage.currentBytesPerSecond.map { (usage.pid, $0) }
        })
        var measurements: [ResourceHogMeasurement] = []

        for group in groups {
            guard let primary = group.processes.max(by: { $0.residentBytes < $1.residentBytes }) else { continue }
            let owners = Set(group.processes.compactMap(\.owner)).sorted()
            let ownerSummary = owners.isEmpty ? "Unknown" : owners.joined(separator: ", ")
            let diskRate = group.processes.reduce(0.0) {
                $0 + ($1.diskReadBytesPerSecond ?? 0) + ($1.diskWriteBytesPerSecond ?? 0)
            }
            let hasDiskRate = group.processes.contains {
                $0.diskReadBytesPerSecond != nil || $0.diskWriteBytesPerSecond != nil
            }
            let networkRate = group.processes.reduce(0.0) {
                $0 + (networkByPID[$1.pid] ?? 0)
            }
            let hasNetworkRate = group.processes.contains { networkByPID[$0.pid] != nil }
            let power = group.processes.reduce(0.0) { $0 + ($1.estimatedPowerWatts ?? 0) }
            let hasPower = group.processes.contains { $0.estimatedPowerWatts != nil }

            appendMeasurement(
                value: Double(group.residentBytes), threshold: Double(thresholds.memoryBytes),
                category: .memory, group: group, primary: primary, owners: ownerSummary, into: &measurements
            )
            appendMeasurement(
                value: group.cpuPercent, threshold: thresholds.cpuPercent,
                category: .cpu, group: group, primary: primary, owners: ownerSummary, into: &measurements
            )
            if hasDiskRate {
                appendMeasurement(
                    value: diskRate, threshold: thresholds.diskBytesPerSecond,
                    category: .disk, group: group, primary: primary, owners: ownerSummary, into: &measurements
                )
            }
            if hasNetworkRate {
                appendMeasurement(
                    value: networkRate, threshold: thresholds.networkBytesPerSecond,
                    category: .network, group: group, primary: primary, owners: ownerSummary, into: &measurements
                )
            }
            if hasPower {
                appendMeasurement(
                    value: power, threshold: thresholds.powerWatts,
                    category: .power, group: group, primary: primary, owners: ownerSummary, into: &measurements
                )
            }
        }

        return measurements
    }

    private static func appendMeasurement(
        value: Double,
        threshold: Double,
        category: ResourceHogCategory,
        group: ApplicationProcessGroup,
        primary: ProcessSnapshot,
        owners: String,
        into measurements: inout [ResourceHogMeasurement]
    ) {
        guard value.isFinite, threshold.isFinite, threshold > 0 else { return }
        measurements.append(
            ResourceHogMeasurement(
                groupID: group.id,
                applicationName: group.name,
                category: category,
                value: value,
                threshold: threshold,
                processCount: group.processes.count,
                ownerSummary: owners,
                primaryProcessIdentity: primary.identity
            )
        )
    }
}

enum ResourceHogQuery {
    static func filter(
        _ findings: [ResourceHogFinding],
        category: ResourceHogCategory?,
        searchText: String
    ) -> [ResourceHogFinding] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return findings.filter { finding in
            (category == nil || finding.category == category)
                && (query.isEmpty
                    || finding.applicationName.localizedCaseInsensitiveContains(query)
                    || finding.ownerSummary.localizedCaseInsensitiveContains(query))
        }
    }
}
