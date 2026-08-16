import Foundation

enum ProcessHierarchy {
    static func forest(from processes: [ProcessSnapshot], searchText: String = "") -> [ProcessTreeNode] {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        var childrenByParent: [Int32: [ProcessSnapshot]] = [:]
        for process in processes {
            if let parentPID = process.parentPID, byPID[parentPID] != nil, parentPID != process.pid {
                childrenByParent[parentPID, default: []].append(process)
            }
        }
        let roots = processes.filter { process in
            guard let parentPID = process.parentPID else { return true }
            return parentPID == process.pid || byPID[parentPID] == nil
        }
        var covered = Set<ProcessSnapshot.Identity>()
        var nodes = roots.sorted(by: processOrder).map {
            build($0, childrenByParent: childrenByParent, ancestors: [], covered: &covered)
        }
        for process in processes.sorted(by: processOrder) where !covered.contains(process.identity) {
            nodes.append(build(process, childrenByParent: childrenByParent, ancestors: [], covered: &covered))
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }
        return nodes.compactMap { filtered($0, query: query) }
    }

    private static func build(
        _ process: ProcessSnapshot,
        childrenByParent: [Int32: [ProcessSnapshot]],
        ancestors: Set<ProcessSnapshot.Identity>,
        covered: inout Set<ProcessSnapshot.Identity>
    ) -> ProcessTreeNode {
        covered.insert(process.identity)
        var nextAncestors = ancestors
        nextAncestors.insert(process.identity)
        let children = (childrenByParent[process.pid] ?? [])
            .filter { !nextAncestors.contains($0.identity) }
            .sorted(by: processOrder)
            .map { build($0, childrenByParent: childrenByParent, ancestors: nextAncestors, covered: &covered) }
        return ProcessTreeNode(process: process, children: children)
    }

    private static func filtered(_ node: ProcessTreeNode, query: String) -> ProcessTreeNode? {
        let matchingChildren = node.children.compactMap { filtered($0, query: query) }
        let matches = node.process.name.localizedCaseInsensitiveContains(query)
            || String(node.process.pid).contains(query)
            || node.process.bundleIdentifier?.localizedCaseInsensitiveContains(query) == true
        guard matches || !matchingChildren.isEmpty else { return nil }
        return .init(process: node.process, children: matchingChildren)
    }

    private static func processOrder(_ lhs: ProcessSnapshot, _ rhs: ProcessSnapshot) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        return comparison == .orderedSame ? lhs.pid < rhs.pid : comparison == .orderedAscending
    }
}
