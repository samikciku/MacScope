import Foundation

struct StorageEntry: Identifiable, Equatable, Sendable {
    let url: URL
    let byteCount: UInt64
    let isDirectory: Bool

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

enum StorageEntryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case files
    case folders

    var id: Self { self }
    var title: String { rawValue.capitalized }
}
