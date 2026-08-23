import SwiftUI

struct ProcessActionResultBanner: View {
    let result: ProcessActionResult
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.outcome.rawValue): \(result.target)").fontWeight(.semibold)
                Text(result.message).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Dismiss", systemImage: "xmark", action: dismiss).labelStyle(.iconOnly)
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.action.rawValue), \(result.outcome.rawValue). \(result.message)")
    }

    private var icon: String {
        switch result.outcome {
        case .completed: "checkmark.circle.fill"
        case .stillRunning: "clock.badge.exclamationmark"
        case .noAction: "hand.raised.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch result.outcome {
        case .completed: .green
        case .stillRunning: .orange
        case .noAction: .secondary
        case .failed: .red
        }
    }
}
