import Foundation
import NonogramKit

/// Bir Kedi Bulmaca bölümünün en iyi sonucu.
struct CatLevelResult: Codable, Equatable {
    var bestScore: Int
    var fewestMistakes: Int
    /// İpucu kullanmadan ve hatasız çözüldü mü (en az bir kez).
    var flawless: Bool
    var completedAt: Date
    var bestTime: TimeInterval?
}

/// Kedi Bulmaca istatistikleri (rozetler ve istatistik ekranı).
struct CatStats: Codable, Equatable {
    var catsFound = 0
    var levelsSolved = 0
    var flawlessLevels = 0
    var findHintsUsed = 0
    var markHintsUsed = 0
    var mistakes = 0
    var bestCombo = 0
    var totalScore = 0
    var playTime: TimeInterval = 0
    /// Art arda hatasız çözülen bölüm sayısı (şu anki ve en iyi).
    var flawlessRun = 0
    var bestFlawlessRun = 0
    var perfectlyMarked = 0
    var fastestSolve: TimeInterval?
}

/// Kedi Bulmaca modu: bölümler, ilerleme, yarım oyunlar ve ipucu hakları.
/// Kayıtlar UserDefaults'ta (küçük ve tek cihazlık veri).
@MainActor
@Observable
final class CatPuzzleModel {
    /// Herkesin başlangıçta aldığı ve Premium'da her gün tamamlanan ipucu hakkı.
    static let maxCharges = 6

    enum Keys {
        static let results = "cat.results"
        static let saved = "cat.saved"
        static let stats = "cat.stats"
        static let findCharges = "cat.charges.find"
        static let markCharges = "cat.charges.mark"
        static let lastRefill = "cat.charges.lastRefill"
        static let lastPlayed = "cat.lastPlayed"
    }

    let pack: CatLevelPack
    private let defaults: UserDefaults
    /// Tür kimliği → katalogdaki tür (piksel portre ve ad için).
    private let breeds: [String: Chapter]

    private(set) var results: [String: CatLevelResult]
    private(set) var saved: [String: CatSnapshot]
    private(set) var stats: CatStats
    private(set) var findCharges: Int
    private(set) var markCharges: Int
    private(set) var lastPlayedLevelID: String?

    init(pack: CatLevelPack, breeds: [Chapter], defaults: UserDefaults) {
        self.pack = pack
        self.defaults = defaults
        self.breeds = Dictionary(breeds.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        results = Self.decode([String: CatLevelResult].self, defaults.data(forKey: Keys.results)) ?? [:]
        saved = Self.decode([String: CatSnapshot].self, defaults.data(forKey: Keys.saved)) ?? [:]
        stats = Self.decode(CatStats.self, defaults.data(forKey: Keys.stats)) ?? CatStats()
        findCharges = defaults.object(forKey: Keys.findCharges) as? Int ?? Self.maxCharges
        markCharges = defaults.object(forKey: Keys.markCharges) as? Int ?? Self.maxCharges
        lastPlayedLevelID = defaults.string(forKey: Keys.lastPlayed)
    }

    static func inMemory(pack: CatLevelPack = .empty, breeds: [Chapter] = []) -> CatPuzzleModel {
        let name = "cat-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return CatPuzzleModel(pack: pack, breeds: breeds, defaults: defaults)
    }

    static func loadPack() -> CatLevelPack {
        (try? CatLevelPack.load(from: .main)) ?? .empty
    }

    var levels: [CatLevel] { pack.levels }

    func breed(_ id: String) -> Chapter? { breeds[id] }

    func number(of level: CatLevel) -> Int { pack.number(of: level) }

    func level(withID id: String) -> CatLevel? { pack.level(withID: id) }

    // MARK: - İlerleme

    func isSolved(_ level: CatLevel) -> Bool { results[level.id] != nil }

    var solvedCount: Int { results.count }

    /// İlk çözülmemiş bölüm (hepsi bittiyse `nil`).
    var nextLevel: CatLevel? {
        levels.first { results[$0.id] == nil }
    }

    /// Bölümler sırayla açılır: çözülenler ve ilk çözülmemiş bölüm oynanabilir.
    func isUnlocked(_ level: CatLevel) -> Bool {
        if results[level.id] != nil { return true }
        return level.id == nextLevel?.id
    }

    /// "Kaldığın yerden devam et": en son yarım bırakılan bölüm, yoksa sıradaki.
    var resumableLevel: CatLevel? {
        if let id = lastPlayedLevelID, saved[id] != nil, let level = level(withID: id) {
            return level
        }
        return nextLevel
    }

    func savedGame(for level: CatLevel) -> CatSnapshot? { saved[level.id] }

    func hasSavedGame(_ level: CatLevel) -> Bool { saved[level.id] != nil }

    func save(_ snapshot: CatSnapshot?, for level: CatLevel) {
        if let snapshot, snapshot.marks.contains(where: { $0 != .blank }) {
            saved[level.id] = snapshot
            lastPlayedLevelID = level.id
            defaults.set(level.id, forKey: Keys.lastPlayed)
        } else {
            saved[level.id] = nil
        }
        // Yalnızca son birkaç yarım oyun tutulur
        if saved.count > 5, let oldest = saved.keys.first(where: { $0 != lastPlayedLevelID }) {
            saved[oldest] = nil
        }
        persist(saved, key: Keys.saved)
    }

    struct Completion {
        let level: CatLevel
        let score: Int
        let mistakes: Int
        let usedHints: Bool
        let elapsed: TimeInterval
        let bestCombo: Int
        let perfectlyMarked: Int
    }

    /// Bölüm bitince: en iyi sonuç ve istatistikler güncellenir. İlk çözümse `true`.
    @discardableResult
    func record(_ completion: Completion, now: Date = Date()) -> Bool {
        let flawless = completion.mistakes == 0 && !completion.usedHints
        let isFirst = results[completion.level.id] == nil
        if var result = results[completion.level.id] {
            result.bestScore = max(result.bestScore, completion.score)
            result.fewestMistakes = min(result.fewestMistakes, completion.mistakes)
            result.flawless = result.flawless || flawless
            result.bestTime = min(result.bestTime ?? .infinity, completion.elapsed)
            results[completion.level.id] = result
        } else {
            results[completion.level.id] = CatLevelResult(
                bestScore: completion.score,
                fewestMistakes: completion.mistakes,
                flawless: flawless,
                completedAt: now,
                bestTime: completion.elapsed
            )
        }
        stats.levelsSolved += 1
        stats.totalScore += completion.score
        stats.playTime += completion.elapsed
        stats.bestCombo = max(stats.bestCombo, completion.bestCombo)
        stats.perfectlyMarked += completion.perfectlyMarked
        if flawless {
            stats.flawlessLevels += 1
            stats.flawlessRun += 1
            stats.bestFlawlessRun = max(stats.bestFlawlessRun, stats.flawlessRun)
        } else {
            stats.flawlessRun = 0
        }
        stats.fastestSolve = min(stats.fastestSolve ?? .infinity, completion.elapsed)
        saved[completion.level.id] = nil
        persist(results, key: Keys.results)
        persist(saved, key: Keys.saved)
        persist(stats, key: Keys.stats)
        return isFirst
    }

    func recordCatFound() {
        stats.catsFound += 1
        persist(stats, key: Keys.stats)
    }

    func recordMistake() {
        stats.mistakes += 1
        persist(stats, key: Keys.stats)
    }

    // MARK: - İpucu hakları

    /// Premium'da her gün (00:00'dan sonra ilk açılışta) haklar 6'ya tamamlanır.
    func refillIfNeeded(isPremium: Bool, today: DayKey) {
        guard isPremium, defaults.integer(forKey: Keys.lastRefill) != today.dayNumber else { return }
        findCharges = max(findCharges, Self.maxCharges)
        markCharges = max(markCharges, Self.maxCharges)
        defaults.set(today.dayNumber, forKey: Keys.lastRefill)
        saveCharges()
    }

    /// Hak varsa bir tane harcar.
    func useFindCharge() -> Bool {
        guard findCharges > 0 else { return false }
        findCharges -= 1
        stats.findHintsUsed += 1
        saveCharges()
        persist(stats, key: Keys.stats)
        return true
    }

    func useMarkCharge() -> Bool {
        guard markCharges > 0 else { return false }
        markCharges -= 1
        stats.markHintsUsed += 1
        saveCharges()
        persist(stats, key: Keys.stats)
        return true
    }

    /// Ödüllü reklam izlenince +1 hak.
    func addFindCharge() {
        findCharges += 1
        saveCharges()
    }

    func addMarkCharge() {
        markCharges += 1
        saveCharges()
    }

    func reset() {
        results = [:]
        saved = [:]
        stats = CatStats()
        lastPlayedLevelID = nil
        for key in [Keys.results, Keys.saved, Keys.stats, Keys.lastPlayed] {
            defaults.removeObject(forKey: key)
        }
    }

    private func saveCharges() {
        defaults.set(findCharges, forKey: Keys.findCharges)
        defaults.set(markCharges, forKey: Keys.markCharges)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
