struct ProcessTreeNode: Identifiable, Equatable, Sendable {
    let process: ProcessSnapshot
    let children: [ProcessTreeNode]

    var id: ProcessSnapshot.Identity { process.identity }
    var outlineChildren: [ProcessTreeNode]? { children.isEmpty ? nil : children }
}
