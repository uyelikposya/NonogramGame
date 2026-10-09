import Foundation

/// Oyuncunun kazanabileceği rozetler.
enum Badge: String, CaseIterable, Identifiable, Codable {
    case graduate
    case firstCard
    case fiveBreeds
    case tenBreeds
    case allBreeds
    case firstGolden
    case fourStars
    case perfectFive
    case dailyWeek
    case hundredSolved
    case starHunter

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .graduate: "graduationcap.fill"
        case .firstCard: "rectangle.portrait.fill"
        case .fiveBreeds: "cat.fill"
        case .tenBreeds: "pawprint.fill"
        case .allBreeds: "books.vertical.fill"
        case .firstGolden: "crown.fill"
        case .fourStars: "star.fill"
        case .perfectFive: "sparkles"
        case .dailyWeek: "flame.fill"
        case .hundredSolved: "checkmark.seal.fill"
        case .starHunter: "star.circle.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .graduate: "Graduate"
        case .firstCard: "First Card"
        case .fiveBreeds: "Cat Collector"
        case .tenBreeds: "Cat Expert"
        case .allBreeds: "Cat Encyclopedia"
        case .firstGolden: "Golden Touch"
        case .fourStars: "Purrfect Score"
        case .perfectFive: "Flawless Five"
        case .dailyWeek: "Daily Habit"
        case .hundredSolved: "Puzzle Master"
        case .starHunter: "Star Hunter"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .graduate: "Finish Kitten School."
        case .firstCard: "Collect your first cat card."
        case .fiveBreeds: "Collect 5 cat breeds."
        case .tenBreeds: "Collect 10 cat breeds."
        case .allBreeds: "Collect every cat breed."
        case .firstGolden: "Win your first Golden Card."
        case .fourStars: "Get 4 stars on a puzzle."
        case .perfectFive: "Solve 5 puzzles in a row without a mistake."
        case .dailyWeek: "Solve the Daily Puzzle 7 days in a row."
        case .hundredSolved: "Solve 100 puzzles."
        case .starHunter: "Collect 100 stars."
        }
    }

    func isEarned(_ progress: BadgeProgress) -> Bool {
        switch self {
        case .graduate: progress.isTutorialDone
        case .firstCard: progress.collectedBreeds >= 1
        case .fiveBreeds: progress.collectedBreeds >= 5
        case .tenBreeds: progress.collectedBreeds >= 10
        case .allBreeds: progress.totalBreeds > 0 && progress.collectedBreeds >= progress.totalBreeds
        case .firstGolden: progress.goldenCards >= 1
        case .fourStars: progress.hasFourStars
        case .perfectFive: progress.perfectRun >= 5
        case .dailyWeek: progress.dailyStreak >= 7
        case .hundredSolved: progress.solvedCount >= 100
        case .starHunter: progress.totalStars >= 100
        }
    }
}

/// Rozet kurallarının baktığı ilerleme özeti.
struct BadgeProgress: Equatable {
    var isTutorialDone = false
    var collectedBreeds = 0
    var totalBreeds = 0
    var goldenCards = 0
    var hasFourStars = false
    var perfectRun = 0
    var dailyStreak = 0
    var solvedCount = 0
    var totalStars = 0
}

/// Kazanılan rozetler (kazanma tarihiyle) ve art arda hatasız çözüm sayısı. Rozetler bir kez
/// kazanılınca kalır; yalnızca "İlerlemeyi Sıfırla" siler.
@MainActor
@Observable
final class BadgeStore {
    static let earnedKey = "badges.earned"
    static let perfectRunKey = "badges.perfectRun"

    private let defaults: UserDefaults
    private(set) var earned: [Badge: Date]
    private(set) var perfectRun: Int

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.earnedKey) as? [String: Double] ?? [:]
        earned = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            Badge(rawValue: key).map { ($0, Date(timeIntervalSince1970: value)) }
        })
        perfectRun = defaults.integer(forKey: Self.perfectRunKey)
    }

    /// Testler ve ekran görüntüsü modu için kalıcı olmayan kayıt.
    static func inMemory() -> BadgeStore {
        let name = "badges-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return BadgeStore(defaults: defaults)
    }

    func isEarned(_ badge: Badge) -> Bool {
        earned[badge] != nil
    }

    /// Her çözümde: hatasızsa seri uzar, hatalıysa sıfırlanır.
    func recordSolve(mistakes: Int) {
        perfectRun = mistakes == 0 ? perfectRun + 1 : 0
        defaults.set(perfectRun, forKey: Self.perfectRunKey)
    }

    /// Yeni kazanılan rozetleri kaydeder ve döner (sıralı).
    @discardableResult
    func update(with progress: BadgeProgress, now: Date = Date()) -> [Badge] {
        let new = Badge.allCases.filter { !isEarned($0) && $0.isEarned(progress) }
        guard !new.isEmpty else { return [] }
        for badge in new { earned[badge] = now }
        save()
        return new
    }

    func reset() {
        earned = [:]
        perfectRun = 0
        defaults.removeObject(forKey: Self.earnedKey)
        defaults.removeObject(forKey: Self.perfectRunKey)
    }

    private func save() {
        defaults.set(Dictionary(uniqueKeysWithValues: earned.map { ($0.key.rawValue, $0.value.timeIntervalSince1970) }),
                     forKey: Self.earnedKey)
    }
}
