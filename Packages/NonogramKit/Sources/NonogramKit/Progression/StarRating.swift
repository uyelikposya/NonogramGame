import Foundation

/// Bulmaca başına en fazla 4 yıldız: hatasız 3, bir hatayla 2, daha fazla hatayla 1;
/// hedef süreden hızlı çözülürse bir hız yıldızı daha.
public enum StarRating {
    public static let maximum = 4

    /// Hız yıldızı için hedef süre. 5×5'te 20 sn, 12×12'de 60 sn; aradaki boyutlarda kare sayısıyla
    /// doğrusal (6→24, 7→28, 8→33, 9→39, 10→45, 11→52). En fazla 60, en küçük eğitim tahtalarında ~12 sn (alt sınır 10).
    public static func speedTarget(rows: Int, columns: Int) -> TimeInterval {
        let seconds = 20 + (Double(rows * columns) - 25) * 40 / 119
        return min(60, max(10, seconds.rounded()))
    }

    /// Hata yıldızları (hız yıldızı hariç). Çözülen her bulmaca en az 1 yıldız alır.
    public static func mistakeStars(_ mistakes: Int) -> Int {
        max(1, 3 - mistakes)
    }

    public static func stars(mistakes: Int, elapsed: TimeInterval, rows: Int, columns: Int) -> Int {
        mistakeStars(mistakes) + (elapsed <= speedTarget(rows: rows, columns: columns) ? 1 : 0)
    }
}
