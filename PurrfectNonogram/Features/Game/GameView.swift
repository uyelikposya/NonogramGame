import NonogramKit
import SwiftUI

/// Aşama 1 prototip oyun ekranı. Tasarım ve tema Aşama 2'de gelecek.
struct GameView: View {
    @State private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss

    init(puzzle: Puzzle, rules: GameRules, onSolved: @escaping (PuzzleCompletion) -> Void) {
        let viewModel = GameViewModel(puzzle: puzzle, rules: rules)
        viewModel.onSolved = onSolved
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let game = viewModel.game
        VStack(spacing: 20) {
            statusBar(game)

            BoardView(
                game: game,
                onDragBegan: { viewModel.dragBegan(at: $0) },
                onDragMoved: { viewModel.dragMoved(to: $0) },
                onDragEnded: { viewModel.dragEnded() }
            )
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal)

            controls(game)
        }
        .padding(.vertical)
        .navigationTitle(Text(verbatim: viewModel.puzzle.title.resolved))
        .navigationBarTitleDisplayMode(.inline)
        // Alta yerleşir ki çözüm sonrası ortaya çıkan görsel görünsün
        .overlay(alignment: .bottom) { resultOverlay(game.status).padding() }
        .animation(.spring, value: game.status)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sensoryFeedback(.error, trigger: viewModel.lastMistake)
    }

    private func statusBar(_ game: NonogramGame) -> some View {
        HStack {
            if let limit = game.rules.mistakeLimit, game.rules.checksMoves {
                HStack(spacing: 4) {
                    ForEach(0..<limit, id: \.self) { index in
                        Image(systemName: index < limit - game.mistakes ? "pawprint.fill" : "pawprint")
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(game.remainingMistakes ?? 0) lives left"))
            }
            Spacer()
            Label {
                Text(Duration.seconds(game.remainingTime ?? game.elapsed), format: .time(pattern: .minuteSecond))
                    .monospacedDigit()
            } icon: {
                Image(systemName: game.rules.timeLimit == nil ? "clock" : "hourglass")
            }
        }
        .font(.headline)
        .padding(.horizontal)
    }

    private func controls(_ game: NonogramGame) -> some View {
        HStack(spacing: 16) {
            Picker("Tool", selection: $viewModel.tool) {
                Label("Fill", systemImage: "square.fill").tag(MarkTool.fill)
                Label("Cross", systemImage: "xmark").tag(MarkTool.cross)
            }
            .pickerStyle(.segmented)

            Button("Undo", systemImage: "arrow.uturn.backward") { viewModel.undo() }
                .labelStyle(.iconOnly)
                .disabled(!game.canUndo)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func resultOverlay(_ status: NonogramGame.Status) -> some View {
        switch status {
        case .playing:
            EmptyView()
        case .won:
            resultCard(title: "Purrfect!", message: "Puzzle solved", button: "Continue") { dismiss() }
        case .lost(let reason):
            resultCard(
                title: reason == .outOfTime ? "Time's up" : "Out of lives",
                message: "Give it another try",
                button: "Back to levels"
            ) { dismiss() }
        }
    }

    private func resultCard(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        button: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.title.bold())
            Text(message).foregroundStyle(.secondary)
            Button(button, action: action).buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
}
