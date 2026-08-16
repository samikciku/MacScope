import Foundation

@MainActor
final class SectionViewModel: ObservableObject {
    let title: String
    let summary: String

    init(title: String, summary: String) {
        self.title = title
        self.summary = summary
    }
}
