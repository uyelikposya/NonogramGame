import Foundation
import NonogramKit

/// Uygulama genelindeki durum: bölüm kataloğu ve oyuncu ilerlemesi.
@MainActor
@Observable
final class AppModel {
    let catalog: LevelCatalog
    let progress: ProgressStore
    /// Günlük bulmaca havuzu (kedi dışı desenler).
    let daily: DailyPuzzles
    let badges: BadgeStore
    /// Testlerde "bugün" sabitlenebilsin diye.
    private let now: () -> Date

    init(
        catalog: LevelCatalog,
        progress: ProgressStore,
        daily: DailyPuzzles = .empty,
        badges: BadgeStore = .inMemory(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.catalog = catalog
        self.progress = progress
        self.daily = daily
        self.badges = badges
        self.now = now
        // 1.0'dan gelen oyuncunun hak ettiği rozetler sessizce verilir
        badges.update(with: badgeProgress)
    }

    static func live() -> AppModel {
        do {
            #if DEBUG
            if DemoContent.isEnabled {
                let model = AppModel(catalog: try CatalogLoader.load(from: .main), progress: .inMemory(), daily: loadDaily(), badges: .inMemory())
                DemoContent.seed(model)
                return model
            }
            #endif
            return AppModel(catalog: try CatalogLoader.load(from: .main), progress: ProgressStore.live(), daily: loadDaily(), badges: BadgeStore(defaults: .standard))
        } catch {
            // Paketlenmiş içerik hatalıysa: testler (ContentValidationTests) bunu yayından önce yakalar
            fatalError("Bölüm içeriği yüklenemedi: \(error)")
        }
    }

    /// Günlük havuz yüklenemezse oyun yine açılır; yalnızca günlük kart görünmez.
    private static func loadDaily() -> DailyPuzzles {
        (try? DailyPuzzles.load(from: .main)) ?? .empty
    }

    /// Bölüm ya da günlük bulmaca.
    func puzzle(withID id: String) -> Puzzle? {
        catalog.puzzle(withID: id) ?? daily.puzzle(withID: id)
    }

    func rules(for puzzle: Puzzle) -> GameRules {
        DailyPuzzles.isDaily(puzzle.id) ? catalog.defaultRules : catalog.rules(for: puzzle)
    }

    /// En son oynanan an (çözüm ya da yarım bırakılan oyun); hatırlatmalar için.
    var lastPlayedAt: Date? {
        progress.records.values.map(\.lastPlayedAt).max()
    }

    // MARK: - Günlük bulmaca

    var today: DayKey { DayKey(now()) }

    var todaysPuzzle: Puzzle? { daily.puzzle(for: today) }

    var isTodaysPuzzleSolved: Bool {
        progress.record(for: today.puzzleID)?.isCompleted ?? false
    }

    /// Kesintisiz günlük bulmaca serisi.
    var dailyStreak: Int {
        let days = progress.completedIDs.compactMap(DayKey.init(puzzleID:))
        return DailyPuzzles.streak(solvedDays: Set(days), today: today)
    }

    var progression: Progression {
        Progression(catalog: catalog, completedIDs: progress.completedIDs)
    }

    @discardableResult
    func record(_ completion: PuzzleCompletion) -> CompletionResult {
        let stars = puzzle(withID: completion.puzzleID).map {
            StarRating.stars(mistakes: completion.mistakes, elapsed: completion.elapsed, rows: $0.rows, columns: $0.columns)
        }
        badges.recordSolve(mistakes: completion.mistakes)
        var result = progress.recordCompletion(completion, stars: stars)
        result.newBadges = badges.update(with: badgeProgress)
        return result
    }

    // MARK: - Rozetler

    var badgeProgress: BadgeProgress {
        let completed = progress.completedIDs
        let tutorial = catalog.chapters.first { $0.kind == .tutorial }
        let solvedStars = catalog.chapters.flatMap { $0.puzzles + $0.premiumPuzzles }.compactMap { stars(for: $0) }
        return BadgeProgress(
            isTutorialDone: tutorial.map { !$0.puzzles.isEmpty && $0.puzzles.allSatisfy { completed.contains($0.id) } } ?? false,
            collectedBreeds: collectedBreeds.count,
            totalBreeds: breeds.count,
            goldenCards: goldenBreeds.count,
            hasFourStars: solvedStars.contains(StarRating.maximum)
                || completed.compactMap(DayKey.init(puzzleID:)).contains { progress.record(for: $0.puzzleID)?.bestStars == StarRating.maximum },
            perfectRun: badges.perfectRun,
            dailyStreak: dailyStreak,
            solvedCount: progress.stats.solvedCount,
            totalStars: solvedStars.reduce(0, +)
        )
    }

    // MARK: - Yıldızlar

    /// Bulmacanın en iyi yıldızı; çözülmediyse `nil`. Eski (1.0) çözümlerde en iyi süre ve en az
    /// hatadan tahmin edilir.
    func stars(for puzzle: Puzzle) -> Int? {
        guard let record = progress.record(for: puzzle.id), record.isCompleted else { return nil }
        if let stars = record.bestStars { return stars }
        return StarRating.stars(
            mistakes: record.fewestMistakes ?? 0,
            elapsed: record.bestTime ?? .infinity,
            rows: puzzle.rows,
            columns: puzzle.columns
        )
    }

    /// Tüm çözülen bulmacaların yıldız toplamı (istatistik ekranı).
    var totalStars: Int {
        catalog.chapters
            .flatMap { $0.puzzles + $0.premiumPuzzles }
            .compactMap { stars(for: $0) }
            .reduce(0, +)
    }

    // MARK: - Ekranlar için özetler

    // MARK: - Kedi koleksiyonu

    /// Oynanabilir kedi türleri. Yeni türler katalog güncellemeleriyle eklenir; toplam sayı arayüzde gösterilmez.
    var breeds: [Chapter] {
        catalog.chapters.filter { $0.kind == .breed && !$0.puzzles.isEmpty }
    }

    /// Bir tür, tüm bulmacaları çözülünce koleksiyona girer.
    func isCollected(_ chapter: Chapter) -> Bool {
        let completed = progress.completedIDs
        return !chapter.puzzles.isEmpty && chapter.puzzles.allSatisfy { completed.contains($0.id) }
    }

    var collectedBreeds: [Chapter] {
        breeds.filter { isCollected($0) }
    }

    /// Türün 9 Altın bulmacası çözülünce Altın Kart kazanılır. Abonelik bitse de kart kalır.
    func isGoldenCollected(_ chapter: Chapter) -> Bool {
        let completed = progress.completedIDs
        return chapter.card != nil && !chapter.premiumPuzzles.isEmpty
            && chapter.premiumPuzzles.allSatisfy { completed.contains($0.id) }
    }

    /// Herkese hediye Altın bulmacalar: bu tür bitince 9 Altın bulmacası abonelik olmadan açılır,
    /// oyuncu Premium'u denemiş olur.
    static let giftedGoldenBreedID = "british-shorthair"

    func isGoldenGift(_ chapter: Chapter) -> Bool {
        chapter.id == Self.giftedGoldenBreedID && !chapter.premiumPuzzles.isEmpty
    }

    /// Altın bulmacalar oynanabilir mi: Premium abonelik ya da tür bitmiş hediye tür.
    func canPlayGolden(_ chapter: Chapter, isPremium: Bool) -> Bool {
        isPremium || (isGoldenGift(chapter) && isCollected(chapter))
    }

    var goldenBreeds: [Chapter] {
        breeds.filter { isGoldenCollected($0) }
    }

    /// Koleksiyonda gösterilen kartlar: türün normal kartı ve (kazanıldıysa) hemen ardından Altın Kartı.
    var collectedCards: [CardSelection] {
        breeds.flatMap { chapter in
            (isCollected(chapter) ? [CardSelection(chapter: chapter, isGolden: false)] : [])
                + (isGoldenCollected(chapter) ? [CardSelection(chapter: chapter, isGolden: true)] : [])
        }
    }

    var hasUnmetBreeds: Bool {
        collectedBreeds.count < breeds.count
    }

    var completedCount: Int {
        let completed = progress.completedIDs
        return catalog.orderedPuzzles.filter { completed.contains($0.id) }.count
    }

    func chapter(withID id: String) -> Chapter? {
        catalog.chapters.first { $0.id == id }
    }

    /// Bölüm içindeki 1'den başlayan sıra numarası (premium bulmacalarda kendi sırası).
    func number(of puzzle: Puzzle) -> Int {
        let chapter = catalog.chapter(containing: puzzle.id)
        let list = catalog.isPremium(puzzle.id) ? chapter?.premiumPuzzles : chapter?.puzzles
        return (list?.firstIndex(of: puzzle) ?? 0) + 1
    }

    func nextPuzzle(after puzzle: Puzzle) -> Puzzle? {
        catalog.puzzle(after: puzzle.id)
    }

    /// Ana ekrandaki "Devam Et" hedefi: önce en son yarım bırakılan açık bulmaca, yoksa sıradaki.
    var resumablePuzzle: Puzzle? {
        let progression = progression
        let inProgress = catalog.orderedPuzzles
            .filter { progress.hasSavedGame(for: $0.id) && progression.isUnlocked($0.id) }
            .max { (progress.record(for: $0.id)?.lastPlayedAt ?? .distantPast) < (progress.record(for: $1.id)?.lastPlayedAt ?? .distantPast) }
        return inProgress ?? progression.nextPlayable
    }

    /// Ayarlardan ilerleme sıfırlanır.
    func resetProgress() {
        progress.resetAll()
        badges.reset()
    }
}

/// Koleksiyonda seçilen kart: bir tür + normal mi Altın mı.
struct CardSelection: Identifiable, Hashable {
    let chapter: Chapter
    let isGolden: Bool

    var id: String { isGolden ? "\(chapter.id)#golden" : chapter.id }
}
