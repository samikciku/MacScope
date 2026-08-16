import Foundation

enum ProcessGrouping {
    static func groups(from processes: [ProcessSnapshot]) -> [ApplicationProcessGroup] {
        let grouped = Dictionary(grouping: processes) { process -> String in
            if let applicationPath = applicationPath(for: process.executablePath) {
                return "app:\(applicationPath)"
            }
            return "process:\(process.pid):\(process.identity.startTime?.timeIntervalSince1970 ?? 0)"
        }

        return grouped.map { id, members in
            let sortedMembers = members.sorted { $0.pid < $1.pid }
            let appPath = sortedMembers.lazy.compactMap { applicationPath(for: $0.executablePath) }.first
            let displayName = appPath.map {
                URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
            } ?? sortedMembers[0].name

            return ApplicationProcessGroup(
                id: id,
                name: displayName,
                applicationPath: appPath,
                processes: sortedMembers,
                residentBytes: clampedSum(sortedMembers.map(\.residentBytes)),
                cpuPercent: sortedMembers.reduce(0) { $0 + $1.cpuPercent },
                threadCount: clampedIntSum(sortedMembers.map(\.threadCount))
            )
        }
    }

    static func sorted(
        _ groups: [ApplicationProcessGroup],
        searchText: String,
        sortField: ProcessSortField,
        sortOrder: ProcessSortOrder
    ) -> [ApplicationProcessGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? groups : groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
                || group.processes.contains {
                    $0.name.localizedCaseInsensitiveContains(query)
                        || String($0.pid).contains(query)
                        || $0.bundleIdentifier?.localizedCaseInsensitiveContains(query) == true
                }
        }

        return filtered.sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sortField {
            case .memory:
                comparison = lhs.residentBytes != rhs.residentBytes
                    ? (lhs.residentBytes < rhs.residentBytes ? .orderedAscending : .orderedDescending)
                    : stableNameComparison(lhs, rhs)
            case .cpu:
                comparison = lhs.cpuPercent != rhs.cpuPercent
                    ? (lhs.cpuPercent < rhs.cpuPercent ? .orderedAscending : .orderedDescending)
                    : stableNameComparison(lhs, rhs)
            case .name:
                comparison = stableNameComparison(lhs, rhs)
            case .pid:
                let leftPID = lhs.processes.first?.pid ?? 0
                let rightPID = rhs.processes.first?.pid ?? 0
                comparison = leftPID == rightPID
                    ? stableNameComparison(lhs, rhs)
                    : (leftPID < rightPID ? .orderedAscending : .orderedDescending)
            }
            return sortOrder == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }
    }

    private static func stableNameComparison(
        _ lhs: ApplicationProcessGroup,
        _ rhs: ApplicationProcessGroup
    ) -> ComparisonResult {
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison != .orderedSame { return nameComparison }
        return lhs.id.compare(rhs.id)
    }

    static func applicationPath(for executablePath: String?) -> String? {
        guard let executablePath else { return nil }
        let components = URL(fileURLWithPath: executablePath).pathComponents
        guard let appIndex = components.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) else {
            return nil
        }
        return NSString.path(withComponents: Array(components.prefix(through: appIndex)))
    }

    private static func clampedSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { result, value in
            let addition = result.addingReportingOverflow(value)
            return addition.overflow ? .max : addition.partialValue
        }
    }

    private static func clampedIntSum(_ values: [Int]) -> Int {
        values.reduce(0) { result, value in
            let addition = result.addingReportingOverflow(value)
            return addition.overflow ? .max : addition.partialValue
        }
    }
}
