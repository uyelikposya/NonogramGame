import NonogramKit
import SwiftUI

/// Rota hedefi: kimliğe göre bulmacayı bulur. `.id` sayesinde "Sonraki Bulmaca"da
/// ViewModel sıfırdan oluşur.
@MainActor
struct GameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    let puzzleID: String

    var body: some View {
        if model.catalog.isPremium(puzzleID), !store.isPremium {
            // Abonelik bitmişse Altın bulmacalar kapanır (kazanılan kartlar kalır)
            ContentUnavailableView(
                "Premium puzzle",
                systemImage: "crown.fill",
                description: Text("Golden puzzles are part of Catgrid Premium.")
            )
            .themedScreen()
        } else if let puzzle = model.catalog.puzzle(withID: puzzleID) {
            GameView(
                puzzle: puzzle,
                rules: model.catalog.rules(for: puzzle),
                savedGame: model.progress.savedGame(for: puzzle.id)
            )
            .id(puzzle.id)
        } else {
            ContentUnavailableView("Puzzle not found", systemImage: "questionmark.circle")
                .themedScreen()
        }
    }
}

@MainActor
struct GameView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: GameViewModel
    @State private var flashingCell: GridPosition?
    @State private var completionResult: CompletionResult?
    /// Bu bulmacayla bir türün tümü çözüldüyse kazanılan kart.
    @State private var newCard: CardSelection?
    /// Küçük kedinin o an söylediği (ipucu).
    @State private var companionLine: CompanionLine?
    @State private var companionLineID = 0

    init(puzzle: Puzzle, rules: GameRules, savedGame: GameSnapshot? = nil) {
        self.init(viewModel: GameViewModel(puzzle: puzzle, rules: rules, savedGame: savedGame))
    }

    /// Testler ekrandaki ViewModel'i doğrudan sürebilsin diye.
    init(viewModel: GameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var game: NonogramGame { viewModel.game }

    var body: some View {
        VStack(spacing: 16) {
            if let lesson = viewModel.puzzle.lesson, game.status == .playing {
                LessonBanner(lesson: lesson)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            GameStatusBar(game: game)

            BoardView(
                game: game,
                activeCell: viewModel.activeCell,
                flashingCell: flashingCell,
                hint: companionHint,
                onDragBegan: { viewModel.dragBegan(at: $0) },
                onDragMoved: { viewModel.dragMoved(to: $0) },
                onDragEnded: { viewModel.dragEnded() }
            )
            .aspectRatio(1, contentMode: .fit)

            // Tahtanın altındaki boşlukta dolaşan kedi; boşluk yoksa görünmez
            CatCompanionView(line: companionLine, isActive: game.status == .playing) {
                askCompanion()
            }
            .layoutPriority(-1)

            if game.status == .playing {
                GameControls(tool: $viewModel.tool, canUndo: game.canUndo) { viewModel.undo() }
            }
        }
        .padding(20)
        .themedScreen()
        .screenTitle(verbatim: game.status == .won ? viewModel.puzzle.title.resolved : "")
        .overlay(alignment: .bottom) {
            resultCard
                .padding(20)
                // Çok büyük yazı boyutunda düğmeler ekrandan taşmasın
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .animation(.spring(duration: 0.5), value: game.status)
        .onAppear {
            viewModel.onSolved = { completion in
                let chapter = model.catalog.chapter(containing: completion.puzzleID)
                let wasCollected = chapter.map { model.isCollected($0) } ?? true
                let wasGolden = chapter.map { model.isGoldenCollected($0) } ?? true
                completionResult = model.record(completion)
                ads.puzzleCompleted(isTutorial: isTutorial)
                var earned: CardSelection?
                if let chapter, chapter.card != nil {
                    if !wasGolden, model.isGoldenCollected(chapter) {
                        earned = CardSelection(chapter: chapter, isGolden: true)
                    } else if !wasCollected, model.isCollected(chapter) {
                        earned = CardSelection(chapter: chapter, isGolden: false)
                    }
                }
                if let earned {
                    // Önce kedi resmi ortaya çıksın, sonra kart
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        newCard = earned
                        audio.play(.card)
                    }
                }
            }
            viewModel.onEvent = { event in
                // Oyuncu hamle yapınca kedi susar
                if companionLine != nil, event != .mistake { companionLine = nil }
                audio.play(event.soundEffect)
                Haptics.play(event)
            }
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
            persistProgress()
        }
        .sheet(item: $newCard) { selection in
            CardDetailSheet(chapter: selection.chapter, isNewCard: true, isGolden: selection.isGolden)
        }
        // Uygulama arka plana geçince (ve kapatılmadan önce) yarım oyun kaydedilir
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.start()
            default:
                viewModel.stop()
                persistProgress()
            }
        }
        .onChange(of: game.status) { _, status in
            if case .lost = status { persistProgress() }
        }
        .onChange(of: game.mistakes) { _, newValue in
            guard newValue > 0 else { return }
            flashMistake()
        }
    }

    private var companionHint: HintFinder.Hint? {
        if case .hint(let hint) = companionLine { return hint }
        return nil
    }

    /// Kediye dokununca: kesin hamle olan bir satır/sütunu gösterir, birkaç saniye sonra susar.
    private func askCompanion() {
        guard game.status == .playing else { return }
        audio.play(.mew)
        Haptics.selection()
        companionLine = HintFinder.bestHint(board: game.board, puzzle: viewModel.puzzle).map { .hint($0) } ?? .noHint
        companionLineID += 1
        let id = companionLineID
        Task {
            try? await Task.sleep(for: .seconds(6))
            if companionLineID == id { companionLine = nil }
        }
    }

    private var isTutorial: Bool {
        model.catalog.chapter(containing: viewModel.puzzle.id)?.kind == .tutorial
    }

    /// Sonuç kartından ayrılırken sırası geldiyse geçiş reklamı araya girer (eğitimde asla).
    private func leave(to route: Route?) {
        audio.play(.tap)
        ads.continueAfterPuzzle {
            if let route {
                router.replaceTop(with: route)
            } else {
                router.pop()
            }
        }
    }

    private func persistProgress() {
        if let snapshot = viewModel.snapshotToSave {
            model.progress.saveGame(snapshot)
        } else {
            model.progress.clearSavedGame(for: viewModel.puzzle.id)
        }
    }

    private func flashMistake() {
        flashingCell = viewModel.lastMistake
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            flashingCell = nil
        }
    }

    // MARK: - Sonuç

    /// Her parça tek argümanlı ayrı bir çeviri anahtarıdır. Çoğul biçimli ("1 mistake / 2 mistakes")
    /// bir anahtara ikinci argüman eklemek, Xcode'un çoğul kuralını yanlış argümana uygulamasına ve
    /// sayının nesne gibi okunup çökmesine yol açıyordu (bkz. Tools/validate_strings.py).
    private func resultDetail(_ result: CompletionResult) -> Text {
        let separator = Text(verbatim: " · ")
        let time = Text("Time \(formatDuration(result.elapsed))")
        if let best = result.previousBest, !result.isNewBest {
            return time + separator + Text("Best \(formatDuration(best))")
        }
        return time + separator + Text("\(result.mistakes) mistakes")
    }

    @ViewBuilder
    private var resultCard: some View {
        switch game.status {
        case .playing:
            EmptyView()
        case .won:
            ResultCard(
                icon: "pawprint.fill",
                tint: theme.success,
                title: "Purrfect!",
                message: Text(verbatim: viewModel.puzzle.title.resolved),
                detail: completionResult.map { resultDetail($0) },
                badge: completionResult?.isNewBest == true ? "New best time!" : nil
            ) {
                if let next = model.nextPuzzle(after: viewModel.puzzle) {
                    Button("Next Puzzle") { leave(to: .game(puzzleID: next.id)) }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Back to Levels") { leave(to: nil) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .lost(let reason):
            ResultCard(
                icon: reason == .outOfTime ? "hourglass" : "heart.slash.fill",
                tint: theme.mistake,
                title: reason == .outOfTime ? "Time's up" : "Out of paws",
                message: Text("Every cat lands on its feet. Give it another try!")
            ) {
                if viewModel.canRevive, store.isPremium {
                    // Premium: devam hakkı reklamsız
                    Button {
                        viewModel.revive()
                    } label: {
                        let title: LocalizedStringKey = reason == .outOfTime ? "Continue: +60 seconds" : "Continue: +1 paw"
                        Label(title, systemImage: "crown.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Try Again") { viewModel.restart() }
                        .buttonStyle(SecondaryButtonStyle())
                } else if viewModel.canRevive, ads.isRewardedReady {
                    Button {
                        Task {
                            if await ads.watchRewardedAd() { viewModel.revive() }
                        }
                    } label: {
                        let title: LocalizedStringKey = reason == .outOfTime ? "Watch an ad: +60 seconds" : "Watch an ad: +1 paw"
                        Label(title, systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Try Again") { viewModel.restart() }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Try Again") { viewModel.restart() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Back to Levels") { router.pop() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Parçalar

/// Kalan patiler (canlar) ve süre.
@MainActor
struct GameStatusBar: View {
    @Environment(\.appTheme) private var theme
    let game: NonogramGame

    var body: some View {
        HStack {
            if let limit = game.rules.mistakeLimit, game.rules.checksMoves {
                HStack(spacing: 6) {
                    ForEach(0..<limit, id: \.self) { index in
                        let isAlive = index < limit - game.mistakes
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(isAlive ? theme.accent : theme.textSecondary.opacity(0.25))
                            .scaleEffect(isAlive ? 1 : 0.85)
                    }
                }
                .animation(.spring, value: game.mistakes)
                .accessibilityElement()
                .accessibilityLabel(Text("\(game.remainingMistakes ?? 0) paws left"))
            }
            Spacer()
            Label {
                Text(Duration.seconds(game.remainingTime ?? game.elapsed), format: .time(pattern: .minuteSecond))
                    .monospacedDigit()
            } icon: {
                Image(systemName: game.rules.timeLimit == nil ? "clock" : "hourglass")
            }
            .foregroundStyle(isRunningOut ? theme.mistake : theme.textSecondary)
        }
        .font(.headline)
    }

    private var isRunningOut: Bool {
        (game.remainingTime ?? .infinity) <= 10
    }
}

/// Doldur / X aracı ve geri al.
@MainActor
struct GameControls: View {
    @Environment(\.appTheme) private var theme
    @Binding var tool: MarkTool
    let canUndo: Bool
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            toolButton(.fill, title: "Fill", systemImage: "square.fill")
            toolButton(.cross, title: "Cross", systemImage: "xmark")

            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(theme.surfaceMuted))
                    .foregroundStyle(canUndo ? theme.textPrimary : theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canUndo)
            .accessibilityLabel(Text("Undo"))
        }

    }

    private func toolButton(_ value: MarkTool, title: LocalizedStringKey, systemImage: String) -> some View {
        let isSelected = tool == value
        return Button {
            if tool != value { Haptics.selection() }
            tool = value
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(isSelected ? theme.accent : theme.surfaceMuted))
                .foregroundStyle(isSelected ? theme.onAccent : theme.textPrimary)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

@MainActor
struct ResultCard<Actions: View>: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let message: Text
    var detail: Text?
    var badge: LocalizedStringKey?
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(tint)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)
            message
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
            if let detail {
                detail
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
            }
            if let badge {
                Label(badge, systemImage: "trophy.fill")
                    .font(.caption.bold())
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(theme.success))
            }
            VStack(spacing: 10) {
                actions()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .card()
    }
}

/// "1:05" biçiminde süre.
func formatDuration(_ interval: TimeInterval) -> String {
    Duration.seconds(interval.rounded()).formatted(.time(pattern: .minuteSecond))
}

extension GameEvent {
    var soundEffect: SoundEffect {
        switch self {
        case .filled: .fill
        case .crossed: .cross
        case .erased: .erase
        case .mistake: .mistake
        case .lineCompleted: .line
        case .solved: .solved
        case .failed: .failed
        }
    }
}
