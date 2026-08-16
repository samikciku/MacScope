import Foundation

actor StorageScanner {
    private let keys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

    func scan(_ root: URL) throws -> [StorageEntry] {
        let children = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        var entries: [StorageEntry] = []
        entries.reserveCapacity(children.count)
        for child in children {
            try Task.checkCancellation()
            let values = try? child.resourceValues(forKeys: keys)
            let isDirectory = values?.isDirectory == true && values?.isSymbolicLink != true
            let size = isDirectory ? directorySize(child) : allocatedSize(values)
            entries.append(StorageEntry(url: child, byteCount: size, isDirectory: isDirectory))
        }
        return entries.sorted { $0.byteCount == $1.byteCount ? $0.name < $1.name : $0.byteCount > $1.byteCount }
    }

    private func directorySize(_ directory: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: UInt64 = 0
        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { return total }
            guard let values = try? item.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values.isRegularFile == true {
                let addition = total.addingReportingOverflow(allocatedSize(values))
                total = addition.overflow ? UInt64.max : addition.partialValue
            }
        }
        return total
    }

    private func allocatedSize(_ values: URLResourceValues?) -> UInt64 {
        let size = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0
        return UInt64(max(0, size))
    }
}
