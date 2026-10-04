import NonogramKit
import SwiftUI

/// Aşama 1 prototipi: kilit sistemini ve motoru denemek için düz liste.
/// Aşama 2'de kedi türü kartları ve bölüm haritasıyla değişecek.
struct LevelListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progression = model.progression
        List {
            ForEach(model.catalog.chapters) { chapter in
                Section {
                    ForEach(Array(chapter.puzzles.enumerated()), id: \.element.id) { offset, puzzle in
                        row(for: puzzle, number: offset + 1, progression: progression)
                    }
                } header: {
                    HStack {
                        Text(verbatim: chapter.title.resolved)
                        Spacer()
                        Text(verbatim: "\(progression.completedCount(in: chapter))/\(chapter.expectedPuzzleCount)")
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Levels")
    }

    @ViewBuilder
    private func row(for puzzle: Puzzle, number: Int, progression: Progression) -> some View {
        let label = HStack {
            Text(verbatim: "\(number). \(puzzle.title.resolved)")
            Spacer()
            Text(verbatim: "\(puzzle.columns)×\(puzzle.rows)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if progression.isCompleted(puzzle.id) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }

        if progression.isUnlocked(puzzle.id) {
            NavigationLink {
                GameView(puzzle: puzzle, rules: model.catalog.rules(for: puzzle)) { completion in
                    model.record(completion)
                }
            } label: {
                label
            }
        } else {
            HStack {
                label
                Image(systemName: "lock.fill")
            }
            .foregroundStyle(.tertiary)
            .accessibilityLabel(Text("Locked"))
        }
    }
}
