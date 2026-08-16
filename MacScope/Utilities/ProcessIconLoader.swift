import AppKit
import SwiftUI

@MainActor
final class ProcessIconLoader {
    static let shared = ProcessIconLoader()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 512
    }

    func image(for executablePath: String?) -> Image {
        guard let executablePath else { return Image(systemName: "terminal") }
        let key = executablePath as NSString
        if let cached = cache.object(forKey: key) {
            return Image(nsImage: cached)
        }
        let icon = NSWorkspace.shared.icon(forFile: executablePath)
        icon.size = NSSize(width: 20, height: 20)
        cache.setObject(icon, forKey: key)
        return Image(nsImage: icon)
    }
}
