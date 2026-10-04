import Foundation
import SwiftData

/// Bir bulmacanın kalıcı kaydı: tamamlanma istatistikleri ve yarım kalan oyun.
/// Bulmaca içeriği JSON'da kalır; burada yalnızca oyuncuya ait veri tutulur.
@Model
final class PuzzleRecord {
    @Attribute(.unique) var puzzleID: String
    /// İlk çözüldüğü an; `nil` ise henüz çözülmedi.
    var firstCompletedAt: Date?
    var timesCompleted: Int
    var bestTime: TimeInterval?
    var fewestMistakes: Int?
    /// Tüm başarılı çözümlerin toplam süresi (istatistik ekranı için).
    var totalSolveTime: TimeInterval
    /// Yarım kalan oyunun JSON'a çevrilmiş `GameSnapshot`'ı.
    var savedGame: Data?
    var lastPlayedAt: Date

    init(puzzleID: String, now: Date = Date()) {
        self.puzzleID = puzzleID
        self.firstCompletedAt = nil
        self.timesCompleted = 0
        self.bestTime = nil
        self.fewestMistakes = nil
        self.totalSolveTime = 0
        self.savedGame = nil
        self.lastPlayedAt = now
    }

    var isCompleted: Bool { firstCompletedAt != nil }
}
