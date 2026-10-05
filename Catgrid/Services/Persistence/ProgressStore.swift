import Foundation
import NonogramKit
import SwiftData

/// Bir bulmaca bittiğinde arayüze dönen özet ("Yeni rekor!" gibi).
struct CompletionResult: Equatable {
    let elapsed: TimeInterval
    let mistakes: Int
    /// Bu çözümden önceki en iyi süre; ilk çözümde `nil`.
    let previousBest: TimeInterval?

    var isNewBest: Bool {
        previousBest.map { elapsed < $0 } ?? false
    }
}

struct PlayerStats: Equatable {
    var solvedCount = 0
    /// Hiç hata yapmadan çözülen bulmacalar.
    var perfectCount = 0
    var totalSolveTime: TimeInterval = 0

    var averageSolveTime: TimeInterval? {
        solvedCount == 0 ? nil : totalSolveTime / Double(solvedCount)
    }
}

/// Oyuncu ilerlemesinin tek kaynağı. SwiftData'yı sarar ve kayıtları bellekte önbelleğe alır
/// ki ekranlar her çizimde veritabanına gitmesin.
@MainActor
@Observable
final class ProgressStore {
    /// Aşama 1-2'de tamamlananlar UserDefaults'ta tutuluyordu; ilk açılışta buradan taşınır.
    static let legacyCompletedKey = "progress.completedPuzzleIDs"

    private(set) var records: [String: PuzzleRecord] = [:]

    private let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let now: () -> Date

    init(container: ModelContainer, legacyDefaults: UserDefaults? = nil, now: @escaping () -> Date = { Date() }) {
        self.container = container
        self.context = container.mainContext
        self.now = now
        let existing = (try? context.fetch(FetchDescriptor<PuzzleRecord>())) ?? []
        records = Dictionary(existing.map { ($0.puzzleID, $0) }, uniquingKeysWith: { first, _ in first })
        if let legacyDefaults { migrateLegacyProgress(from: legacyDefaults) }
    }

    /// Diskte kalıcı kayıt. Veritabanı açılamazsa (bozuk dosya, dolu disk) uygulama çökmez:
    /// önce dosya silinip yeniden kurulur, o da olmazsa oturum bellekte sürer.
    static func live() -> ProgressStore {
        let configuration = ModelConfiguration()
        if let container = try? ModelContainer(for: PuzzleRecord.self, configurations: configuration) {
            return ProgressStore(container: container, legacyDefaults: .standard)
        }
        let url = configuration.url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        if let container = try? ModelContainer(for: PuzzleRecord.self, configurations: configuration) {
            return ProgressStore(container: container, legacyDefaults: .standard)
        }
        return inMemory()
    }

    /// Testler ve önizlemeler için bellekte kayıt.
    static func inMemory() -> ProgressStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // Bellek içi kap oluşturmak yalnızca şema hatalıysa başarısız olur; bu bir programlama hatasıdır
        let container = try! ModelContainer(for: PuzzleRecord.self, configurations: configuration)
        return ProgressStore(container: container)
    }

    // MARK: - Tamamlanma

    var completedIDs: Set<String> {
        Set(records.values.filter(\.isCompleted).map(\.puzzleID))
    }

    func record(for puzzleID: String) -> PuzzleRecord? {
        records[puzzleID]
    }

    @discardableResult
    func recordCompletion(_ completion: PuzzleCompletion) -> CompletionResult {
        let record = fetchOrCreate(completion.puzzleID)
        let result = CompletionResult(
            elapsed: completion.elapsed,
            mistakes: completion.mistakes,
            previousBest: record.bestTime
        )
        if record.firstCompletedAt == nil { record.firstCompletedAt = completion.completedAt }
        record.timesCompleted += 1
        record.totalSolveTime += completion.elapsed
        record.bestTime = min(record.bestTime ?? .infinity, completion.elapsed)
        record.fewestMistakes = min(record.fewestMistakes ?? .max, completion.mistakes)
        record.savedGame = nil
        record.lastPlayedAt = completion.completedAt
        save()
        return result
    }

    // MARK: - Yarım kalan oyun

    func savedGame(for puzzleID: String) -> GameSnapshot? {
        guard let data = records[puzzleID]?.savedGame else { return nil }
        return try? decoder.decode(GameSnapshot.self, from: data)
    }

    func hasSavedGame(for puzzleID: String) -> Bool {
        records[puzzleID]?.savedGame != nil
    }

    func saveGame(_ snapshot: GameSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        let record = fetchOrCreate(snapshot.puzzleID)
        record.savedGame = data
        record.lastPlayedAt = now()
        save()
    }

    func clearSavedGame(for puzzleID: String) {
        guard let record = records[puzzleID], record.savedGame != nil else { return }
        record.savedGame = nil
        save()
    }

    // MARK: - İstatistik

    var stats: PlayerStats {
        records.values.reduce(into: PlayerStats()) { stats, record in
            guard record.isCompleted else { return }
            stats.solvedCount += 1
            if record.fewestMistakes == 0 { stats.perfectCount += 1 }
            stats.totalSolveTime += record.totalSolveTime
        }
    }

    /// Ayarlar → "İlerlemeyi Sıfırla".
    func resetAll() {
        for record in records.values { context.delete(record) }
        records.removeAll()
        save()
    }

    // MARK: - Yardımcılar

    private func fetchOrCreate(_ puzzleID: String) -> PuzzleRecord {
        if let record = records[puzzleID] { return record }
        let record = PuzzleRecord(puzzleID: puzzleID, now: now())
        context.insert(record)
        records[puzzleID] = record
        return record
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("İlerleme kaydedilemedi: \(error)")
        }
    }

    private func migrateLegacyProgress(from defaults: UserDefaults) {
        guard let ids = defaults.stringArray(forKey: Self.legacyCompletedKey) else { return }
        for id in ids {
            let record = fetchOrCreate(id)
            if record.firstCompletedAt == nil {
                record.firstCompletedAt = now()
                record.timesCompleted = max(record.timesCompleted, 1)
            }
        }
        save()
        defaults.removeObject(forKey: Self.legacyCompletedKey)
    }
}
