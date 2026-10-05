import NonogramKit
import SwiftUI

/// Eğitim bulmacalarının üstünde, o bölümün öğrettiği kuralı anlatan balon.
@MainActor
struct LessonBanner: View {
    @Environment(\.appTheme) private var theme
    let lesson: TutorialLesson
    @State private var isExpanded = true

    var body: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(theme.accent)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    if isExpanded {
                        Text(lesson.message)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .card(fill: theme.surface, cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

extension TutorialLesson {
    var title: LocalizedStringResource {
        switch self {
        case .tapToFill: "Tap to fill"
        case .fullLines: "Full lines"
        case .emptyLines: "Empty lines"
        case .markWithCross: "Mark with X"
        case .multipleBlocks: "Several blocks"
        case .overlap: "Find the overlap"
        case .edges: "Use the edges"
        case .crossReference: "Rows meet columns"
        case .mistakesAndLives: "Mind your paws"
        case .difficulty: "Choose your difficulty"
        case .graduation: "Graduation"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .tapToFill:
            "Numbers tell you how many squares in a line are filled. A 3 means three filled squares side by side. Tap a square to fill it."
        case .fullLines:
            "When a clue is as long as the line, the whole line is filled. Start there!"
        case .emptyLines:
            "A 0 means the line has no filled squares at all."
        case .markWithCross:
            "Switch to the X tool to mark squares you know are empty. It keeps your thinking tidy."
        case .multipleBlocks:
            "1 1 1 means three separate blocks with at least one empty square between each of them."
        case .overlap:
            "A long block covers the middle of the line wherever it starts. Fill the squares every position shares."
        case .edges:
            "A filled square touching the edge tells you exactly where a block begins."
        case .crossReference:
            "Every square belongs to a row and a column. Use what one tells you to solve the other."
        case .mistakesAndLives:
            "From now on each wrong move costs a paw. Lose all three and the puzzle starts over."
        case .difficulty:
            "The button next to the timer sets the difficulty. On Easy, finished lines are crossed out for you. On Hard, you mark every empty square yourself. Try both!"
        case .graduation:
            "You know all the rules. Solve this one on your own!"
        }
    }
}
