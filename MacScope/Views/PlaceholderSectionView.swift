import SwiftUI

struct PlaceholderSectionView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView(
            section.title,
            systemImage: section.systemImage,
            description: Text("This section is ready for its monitoring engine in a later implementation phase.")
        )
        .navigationTitle(section.title)
    }
}
