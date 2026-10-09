import NonogramKit
import StoreKit
import SwiftUI

/// Günlük bulmaca: o günün bulmacası, kendi kaydıyla.
@MainActor
struct DailyScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let puzzle = model.todaysPuzzle {
            GameView(
                puzzle: puzzle,
                rules: model.rules(for: puzzle),
                savedGame: model.progress.savedGame(for: puzzle.id)
            )
            .id(puzzle.id)
        } else {
            ContentUnavailableView("Puzzle not found", systemImage: "questionmark.circle")
                .themedScreen()
        }
    }
}

/// Rota hedefi: kimliğe göre bulmacayı bulur. `.id` sayesinde "Sonraki Bulmaca"da
/// ViewModel sıfırdan oluşur.
@MainActor
struct GameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    let puzzleID: String

    var body: some View {
        if model.catalog.isPremium(puzzleID),
           let chapter = model.catalog.chapter(containing: puzzleID),
           !model.canPlayGolden(chapter, isPremium: store.isPremium) {
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
    @Environment(\.requestReview) private var requestReview
    /// Değerlendirme isteğinin en son sorulduğu çözüm eşiği.
    @AppStorage(RatingPolicy.lastThresholdKey) private var lastRatingThreshold = 0

    @State private var viewModel: GameViewModel
    @State private var flashingCell: GridPosition?
    @State private var completionResult: CompletionResult?
    /// Bu bulmacayla bir türün tümü çözüldüyse kazanılan kart.
    @State private var newCard: CardSelection?
    /// Kart kazanıldı ama penceresi henüz kapanmadı: o sırada sonuç kartındaki düğmeler gizli,
    /// oyuncu yanlışlıkla sonraki bölüme geçip kartı kaçırmasın.
    @State private var isCardPending = false
    /// Bu çözümle kilidi açılan yeni kedi türü (önceki türün yarısı çözülünce).
    @State private var newlyUnlockedChapter: Chapter?
    @AppStorage(SettingsKeys.hardMode) private var isHardMode = false
    @AppStorage(SettingsKeys.playMode) private var playMode = PlayMode.dopamine
    /// Dopamin modu: satır parıltısı ve bitişte konfeti.
    @State private var lineGlow: LineGlow?
    @State private var confettiStart: Date?
    @State private var difficultyNote: Bool?
    /// Küçük kedinin o an söylediği (ipucu).
    @State private var companionLine: CompanionLine?
    @State private var companionLineID = 0
    /// Muffin her yeni sözde kısa bir süre konuşur; hata yapınca bir an şaşırır.
    @State private var muffinSpeech = 1
    @State private var muffinReaction: MuffinView.Pose?

    init(puzzle: Puzzle, rules: GameRules, savedGame: GameSnapshot? = nil) {
        self.init(viewModel: GameViewModel(puzzle: puzzle, rules: rules, savedGame: savedGame))
    }

    /// Testler ekrandaki ViewModel'i doğrudan sürebilsin diye.
    init(viewModel: GameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var game: NonogramGame { viewModel.game }

    private var isDaily: Bool { DailyPuzzles.isDaily(viewModel.puzzle.id) }

    var body: some View {
        VStack(spacing: 16) {
            if let lesson = viewModel.puzzle.lesson, game.status != .lost(.outOfTime) {
                MuffinLessonBanner(lesson: lesson, pose: muffinPose(for: lesson), speechID: muffinSpeech) {
                    model.skipTutorial()
                    router.popToRoot()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            GameStatusBar(game: game, isHardMode: $isHardMode) {
                audio.play(.tap)
                withAnimation(.snappy) { viewModel.pause() }
            }
                .overlay(alignment: .bottom) {
                    if let hard = difficultyNote {
                        Text(hard ? LocalizedStringKey("Hard: you place every X yourself.") : LocalizedStringKey("Easy: finished lines are crossed out for you."))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(theme.surface).shadow(color: .black.opacity(0.1), radius: 6, y: 2))
                            .offset(y: 44)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .allowsHitTesting(false)
                    }
                }
                .zIndex(1)

            BoardView(
                game: game,
                activeCell: viewModel.activeCell,
                flashingCell: flashingCell,
                hint: companionHint ?? guidedStep?.hint,
                pointer: guidedStep?.cell,
                lineGlow: lineGlow,
                onDragBegan: { viewModel.dragBegan(at: $0) },
                onDragMoved: { viewModel.dragMoved(to: $0) },
                onDragEnded: { viewModel.dragEnded() }
            )
            // Tahta bulmacanın kendi oranında (ipuçlarıyla birlikte): uzun bulmacalar (10x20 gibi)
            // kare bir alana sıkışmaz, ekranın boş yüksekliğini kullanır
            .aspectRatio(boardAspectRatio, contentMode: .fit)

            // Tahtanın altındaki boşlukta dolaşan kedi; boşluk yoksa görünmez
            CatCompanionView(line: companionLine, isActive: game.status == .playing, coat: companionCoat) {
                askCompanion()
            }
            // Tahta büyüse de yardımcı kediye her zaman yer kalsın
            .frame(minHeight: CatCompanionView.minimumHeight)
            .layoutPriority(-1)

            if game.status == .playing {
                GameControls(tool: $viewModel.tool, canUndo: game.canUndo) { viewModel.undo() }
            }
        }
        // Büyük tahtalarda kenar boşluğu daralır, kareler büyür
        .padding(.horizontal, isLargeBoard ? 10 : 20)
        .padding(.vertical, 20)
        .overlay {
            if viewModel.isPaused {
                PauseMenu(
                    onContinue: {
                        audio.play(.tap)
                        withAnimation(.snappy) { viewModel.resume() }
                    },
                    onSettings: {
                        audio.play(.tap)
                        router.push(.settings)
                    },
                    onHome: {
                        audio.play(.tap)
                        router.popToRoot()
                    },
                    onRestart: {
                        audio.play(.tap)
                        withAnimation(.snappy) { viewModel.restart() }
                    }
                )
                .transition(.opacity)
            }
        }
        .themedScreen()
        .screenTitle(isDaily ? Text("Daily Puzzle") : Text(verbatim: chapter?.title.resolved ?? ""), subtitle: subtitle)
        // Hangi kedi türündesin: başlığın yanında türün portresi
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let chapter, chapter.kind == .breed {
                    ChapterBadge(chapter: chapter, size: 38)
                        .accessibilityHidden(true)
                }
            }
        }
        .overlay {
            ConfettiView(start: confettiStart)
                .ignoresSafeArea()
        }
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
                let unlockedBefore = Set(model.catalog.chapters.filter { model.progression.isUnlocked($0) }.map(\.id))
                completionResult = model.record(completion)
                let progression = model.progression
                newlyUnlockedChapter = model.breeds.first { !unlockedBefore.contains($0.id) && progression.isUnlocked($0) }
                ads.puzzleCompleted(isTutorial: isTutorial)
                // Ders bitti: Muffin sevinçle miyavlar
                if viewModel.puzzle.lesson != nil {
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        audio.play(.muffinJoy)
                    }
                }
                var earned: CardSelection?
                if let chapter, chapter.card != nil {
                    if !wasGolden, model.isGoldenCollected(chapter) {
                        earned = CardSelection(chapter: chapter, isGolden: true)
                    } else if !wasCollected, model.isCollected(chapter) {
                        earned = CardSelection(chapter: chapter, isGolden: false)
                    }
                }
                // Mutlu bir an: hatasız çözüm, kart beklenmiyor, belli sayıda bulmacadan sonra
                if earned == nil, !isTutorial, completion.mistakes == 0,
                   let threshold = RatingPolicy.threshold(solved: model.progress.stats.solvedCount, lastPrompted: lastRatingThreshold) {
                    lastRatingThreshold = threshold
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        requestReview()
                    }
                }
                if let earned {
                    isCardPending = true
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
                let isDopamine = playMode == .dopamine
                switch event {
                case .lineCompleted where isDopamine:
                    audio.play(.combo)
                    celebrateLine()
                case .solved where isDopamine:
                    audio.play(.fanfare)
                    let start = Date()
                    confettiStart = start
                    Task {
                        try? await Task.sleep(for: .seconds(2.8))
                        if confettiStart == start { confettiStart = nil }
                    }
                default:
                    audio.play(event.soundEffect)
                }
                Haptics.play(event)
            }
            viewModel.autoCrosses = !isHardMode
            viewModel.start()
            // Muffin dersi anlatmaya başlar: soru cümlesiyse soru tonunda miyavlar
            if let lesson = viewModel.puzzle.lesson, game.status == .playing {
                let isQuestion = String(localized: lesson.message).trimmingCharacters(in: .whitespaces).hasSuffix("?")
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    audio.play(isQuestion ? .muffinQuestion : .muffinTalk)
                }
            }
        }
        .onChange(of: isHardMode) { _, hard in
            viewModel.autoCrosses = !hard
            Haptics.selection()
            withAnimation(.snappy) { difficultyNote = hard }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if difficultyNote == hard { withAnimation(.easeOut) { difficultyNote = nil } }
            }
        }
        .onDisappear {
            viewModel.stop()
            persistProgress()
        }
        .sheet(item: $newCard, onDismiss: { isCardPending = false }) { selection in
            CardDetailSheet(
                chapter: selection.chapter,
                isNewCard: true,
                isGolden: selection.isGolden,
                unlocksGoldenGift: !selection.isGolden && model.isGoldenGift(selection.chapter) && !store.isPremium
            )
        }
        // Uygulama arka plana geçince (ve kapatılmadan önce) oyun duraklar ve yarım oyun kaydedilir;
        // dönünce duraklatma menüsü karşılar
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: viewModel.start()
            default:
                viewModel.pause()
                persistProgress()
            }
        }
        .onChange(of: game.status) { _, status in
            if case .lost = status { persistProgress() }
        }
        .onChange(of: game.mistakes) { _, newValue in
            guard newValue > 0 else { return }
            flashMistake()
            if viewModel.puzzle.lesson != nil {
                audio.play(.muffinOops)
                muffinReaction = .oops
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    muffinReaction = nil
                }
            }
        }
    }

    private var chapter: Chapter? {
        model.catalog.chapter(containing: viewModel.puzzle.id)
    }

    /// Başlığın altında: bölüm sırası; çözülünce resmin adı.
    private var subtitle: Text? {
        if game.status == .won { return Text(verbatim: viewModel.puzzle.title.resolved) }
        if isDaily, let day = DayKey(puzzleID: viewModel.puzzle.id) {
            return Text(day.date, format: .dateTime.day().month(.wide))
        }
        guard let chapter else { return nil }
        let number = model.number(of: viewModel.puzzle)
        if model.catalog.isPremium(viewModel.puzzle.id) {
            return Text("Golden puzzle \(number) of \(chapter.premiumPuzzles.count)")
        }
        if chapter.kind == .tutorial {
            return Text("Lesson \(number) of \(chapter.puzzles.count)")
        }
        return Text("Puzzle \(number) of \(chapter.puzzles.count)")
    }

    /// Sonraki bulmaca başka bir türdeyse düğme "Sonraki kedi: …" der.
    @ViewBuilder
    private func nextButton(_ next: Puzzle) -> some View {
        let nextChapter = model.catalog.chapter(containing: next.id)
        Button {
            leave(to: .game(puzzleID: next.id))
        } label: {
            if let nextChapter, nextChapter.id != chapter?.id {
                Label("Next Cat: \(nextChapter.title.resolved)", systemImage: "pawprint.fill")
            } else {
                Text("Next Puzzle")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("result.next")
    }

    private func muffinPose(for lesson: TutorialLesson) -> MuffinView.Pose {
        if game.status == .won { return .cheer }
        return muffinReaction ?? lesson.muffinPose
    }

    /// Eğitimin ilk 9 dersinde: mantıkla kesinleşen bir satır/sütun vurgulanır ve pati o
    /// çizgide doldurulacak kareyi gösterir. Her hamleden sonra bir sonrakine geçer.
    private static let guidedLessons: Set<TutorialLesson> = [
        .firstSquare, .tapToFill, .fullLines, .emptyLines, .markWithCross,
        .multipleBlocks, .overlap, .edges, .crossReference,
    ]

    private var guidedStep: (hint: HintFinder.Hint, cell: GridPosition)? {
        let puzzle = viewModel.puzzle
        guard let lesson = puzzle.lesson, Self.guidedLessons.contains(lesson),
              game.status == .playing, !viewModel.isPaused,
              let hint = HintFinder.bestHint(board: game.board, puzzle: puzzle)
        else { return nil }
        let length = hint.axis == .row ? puzzle.columns : puzzle.rows
        let positions = (0..<length).map {
            hint.axis == .row ? GridPosition(row: hint.index, column: $0) : GridPosition(row: $0, column: hint.index)
        }
        let line: [Bool?] = positions.map { position in
            switch game.board[position] {
            case .filled: true
            case .crossed: false
            case .blank: nil
            }
        }
        let clue = hint.axis == .row ? puzzle.rowClues[hint.index] : puzzle.columnClues[hint.index]
        guard let solved = LineSolver.solve(line, clue: clue),
              let index = positions.indices.first(where: { line[$0] == nil && solved[$0] == true })
        else { return nil }
        return (hint, positions[index])
    }

    /// Genişlik / yükseklik: ipucu sütunları dahil kare sayısı oranı.
    private var boardAspectRatio: CGFloat {
        let puzzle = viewModel.puzzle
        let rowClueSlots = max(puzzle.rowClues.map(\.count).max() ?? 1, 1)
        let columnClueSlots = max(puzzle.columnClues.map(\.count).max() ?? 1, 1)
        return CGFloat(puzzle.columns + rowClueSlots) / CGFloat(puzzle.rows + columnClueSlots)
    }

    private var isLargeBoard: Bool {
        max(viewModel.puzzle.rows, viewModel.puzzle.columns) > 12
    }

    /// Kedi türü bölümünde yardımcı kedi o türün renklerinde.
    private var companionCoat: CatCoat {
        guard let chapter, chapter.kind == .breed, let portrait = chapter.portrait else { return .ginger }
        return CatCoat(portrait: portrait) ?? .ginger
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

    /// Dopamin modu: tamamlanan satır/sütun kısa bir süre parlar.
    private func celebrateLine() {
        let lines = viewModel.completedLines
        let glow = LineGlow(row: lines.row, column: lines.column, start: Date())
        lineGlow = glow
        Task {
            try? await Task.sleep(for: .seconds(LineGlow.duration + 0.05))
            if lineGlow == glow { lineGlow = nil }
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

    /// Hız yıldızı kaçtıysa hedef süre hatırlatılır.
    private func speedStarNote(_ result: CompletionResult) -> Text? {
        let puzzle = viewModel.puzzle
        let target = StarRating.speedTarget(rows: puzzle.rows, columns: puzzle.columns)
        guard result.elapsed > target else { return nil }
        return Text("Solve within \(formatDuration(target)) for the 4th star")
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
                badge: isDaily ? nil : (completionResult?.isNewBest == true ? "New best time!" : nil),
                stars: completionResult?.stars,
                starNote: completionResult.flatMap { speedStarNote($0) },
                newBadges: completionResult?.newBadges ?? [],
                artwork: viewModel.puzzle.artwork
            ) {
                if isCardPending {
                    // Kart penceresi açılana/kapanana kadar geçiş düğmeleri yok
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Your card is on its way…")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                } else if isDaily {
                    Label("\(model.dailyStreak)-day streak", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(theme.accent)
                        .accessibilityIdentifier("result.streak")
                    Text("A new puzzle is waiting tomorrow.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Button("Home") { router.popToRoot() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    let next = model.nextPuzzle(after: viewModel.puzzle)
                    if let next {
                        nextButton(next)
                    }
                    if let unlocked = newlyUnlockedChapter,
                       let first = unlocked.puzzles.first,
                       next.flatMap({ model.catalog.chapter(containing: $0.id)?.id }) != unlocked.id {
                        // Yeni tür açıldı: oyuncu isterse hemen yeni kediye geçebilir
                        Button {
                            leave(to: .game(puzzleID: first.id))
                        } label: {
                            Label("New cat unlocked: \(unlocked.title.resolved)", systemImage: "lock.open.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("result.newCat")
                    }
                    Button("Back to Levels") { leave(to: nil) }
                        .buttonStyle(SecondaryButtonStyle())
                }
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
                if isDaily {
                    Button("Home") { router.popToRoot() }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Back to Levels") { router.pop() }
                        .buttonStyle(SecondaryButtonStyle())
                }
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
    @Binding var isHardMode: Bool
    let onPause: () -> Void

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

            // Zorluk: "Zor"da tamamlanan satırlara otomatik X konmaz
            Button {
                isHardMode.toggle()
            } label: {
                Label(isHardMode ? LocalizedStringKey("Hard") : LocalizedStringKey("Easy"), systemImage: isHardMode ? "flame.fill" : "leaf.fill")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(isHardMode ? theme.mistake.opacity(0.15) : theme.surfaceMuted))
                    .foregroundStyle(isHardMode ? theme.mistake : theme.accent)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.leading, 6)
            .accessibilityLabel(Text("Difficulty"))
            .accessibilityValue(isHardMode ? Text("Hard") : Text("Easy"))
            .accessibilityIdentifier("game.difficulty")

            if game.status == .playing {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.surfaceMuted))
                        .foregroundStyle(theme.textPrimary)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.leading, 4)
                .accessibilityLabel(Text("Pause"))
                .accessibilityIdentifier("game.pause")
            }
        }
        .font(.headline)
    }

    private var isRunningOut: Bool {
        (game.remainingTime ?? .infinity) <= 10
    }
}

/// Duraklatınca tahtanın üstünü kapatan menü: Devam, Ayarlar, Ana Sayfa.
@MainActor
struct PauseMenu: View {
    @Environment(\.appTheme) private var theme
    let onContinue: () -> Void
    let onSettings: () -> Void
    let onHome: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            // Tahta görünmesin: duraklatıp düşünmek hile olmasın
            theme.background
                .opacity(0.97)
                .contentShape(Rectangle())
            VStack(spacing: 14) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent)
                Text("Paused")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("Take a break. Your puzzle will wait for you.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("pause.continue")
                    Button(action: onRestart) {
                        Label("Start Over", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("pause.restart")
                    Button(action: onSettings) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("pause.settings")
                    Button(action: onHome) {
                        Label("Home", systemImage: "house.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("pause.home")
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .card()
            .padding(.horizontal, 4)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
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
    var stars: Int?
    var starNote: Text?
    var newBadges: [Badge] = []
    /// Çözülen resim: kartla birlikte gelir (tahtanın kartın altında kalmaması için).
    var artwork: Matrix<RGBColor?>?
    @ViewBuilder let actions: () -> Actions
    @State private var showsStars = false

    var body: some View {
        VStack(spacing: 14) {
            if let artwork {
                ArtworkThumbnail(artwork: artwork)
                    .padding(10)
                    .frame(maxWidth: 150, maxHeight: 130)
                    .background(RoundedRectangle(cornerRadius: 16).fill(theme.surfaceMuted))
            } else {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)
            message
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
            if let stars {
                StarsView(count: stars, size: 26)
                    .scaleEffect(showsStars ? 1 : 0.4)
                    .opacity(showsStars ? 1 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.25)) { showsStars = true }
                    }
                if let starNote {
                    starNote
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            ForEach(newBadges) { badge in
                Label {
                    Text("New badge: \(String(localized: badge.title))")
                } icon: {
                    Image(systemName: badge.icon)
                }
                .font(.caption.bold())
                .foregroundStyle(Gold.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Gold.foil))
                .accessibilityIdentifier("result.badge")
            }
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

/// Uygulamayı değerlendirme isteği: belli çözüm sayılarında, en fazla eşik başına bir kez.
/// iOS ayrıca yılda en fazla üç kez gösterir.
enum RatingPolicy {
    static let lastThresholdKey = "rating.lastThreshold"
    static let thresholds = [10, 40, 120]

    /// Bu çözümle ulaşılan ve henüz sorulmamış en yüksek eşik.
    static func threshold(solved: Int, lastPrompted: Int) -> Int? {
        thresholds.last { $0 <= solved && $0 > lastPrompted }
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
