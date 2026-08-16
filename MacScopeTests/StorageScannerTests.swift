import Foundation
import Testing
@testable import MacScope

struct StorageScannerTests {
    @Test func scansTopLevelFilesAndRecursiveFolderSizesLargestFirst() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "MacScopeStorageScanner-\(UUID().uuidString)", directoryHint: .isDirectory)
        let folder = root.appending(path: "Folder", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 64 * 1_024).write(to: folder.appending(path: "nested.bin"))
        try Data(repeating: 2, count: 1_024).write(to: root.appending(path: "small.bin"))

        let entries = try await StorageScanner().scan(root)
        let scannedFolder = try #require(entries.first { $0.name == "Folder" })
        let scannedFile = try #require(entries.first { $0.name == "small.bin" })

        #expect(entries.count == 2)
        #expect(scannedFolder.isDirectory)
        #expect(!scannedFile.isDirectory)
        #expect(scannedFolder.byteCount > scannedFile.byteCount)
        #expect(entries.first?.name == "Folder")
    }
}
