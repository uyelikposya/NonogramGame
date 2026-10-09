import Foundation
import UserNotifications

/// "Miyavdirim": günde en fazla bir kez, yalnızca o gün oynanmadıysa gelen yerel hatırlatma.
///
/// Tekrarlayan bildirim yerine önümüzdeki günler için tek tek bildirim kurulur; böylece oyuncu
/// o gün zaten oynadıysa bugünün bildirimi atlanır. Uygulama her arka plana geçtiğinde yeniden
/// kurulur. Oyuncu bir hafta hiç açmazsa bildirimler kendiliğinden durur (rahatsız etmemek için).
@MainActor
@Observable
final class ReminderManager {
    static let enabledKey = "reminder.enabled"
    static let hourKey = "reminder.hour"
    static let minuteKey = "reminder.minute"
    static let askedKey = "reminder.asked"
    /// Bu kadar bulmaca çözülünce ana ekranda bir kez sorulur.
    static let offerAfterSolved = 3
    static let daysAhead = 7
    private static let idPrefix = "catgrid.reminder."

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter?

    private(set) var isEnabled: Bool
    private(set) var hasAsked: Bool
    var hour: Int {
        didSet { defaults.set(hour, forKey: Self.hourKey) }
    }
    var minute: Int {
        didSet { defaults.set(minute, forKey: Self.minuteKey) }
    }

    init(defaults: UserDefaults = .standard, center: UNUserNotificationCenter? = .current()) {
        self.defaults = defaults
        self.center = center
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        hasAsked = defaults.bool(forKey: Self.askedKey)
        hour = defaults.object(forKey: Self.hourKey) as? Int ?? 19
        minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 0
    }

    func shouldOffer(solvedCount: Int) -> Bool {
        !hasAsked && !isEnabled && solvedCount >= Self.offerAfterSolved
    }

    func markAsked() {
        hasAsked = true
        defaults.set(true, forKey: Self.askedKey)
    }

    /// Bildirim izni ister; verilirse hatırlatmayı açar. İzin yoksa `false`.
    func enable() async -> Bool {
        markAsked()
        guard let center else { return false }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        setEnabled(granted)
        return granted
    }

    func disable() {
        setEnabled(false)
        center?.removePendingNotificationRequests(withIdentifiers: (0..<Self.daysAhead + 1).map { Self.idPrefix + "\($0)" })
    }

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: Self.enabledKey)
    }

    /// Önümüzdeki günlerin hatırlatmalarını yeniden kurar.
    func reschedule(lastPlayedAt: Date?, streak: Int, now: Date = Date()) async {
        guard let center else { return }
        let ids = (0..<Self.daysAhead + 1).map { Self.idPrefix + "\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let playedToday = lastPlayedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let dates = ReminderSchedule.dates(now: now, hour: hour, minute: minute, playedToday: playedToday, days: Self.daysAhead, calendar: calendar)
        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Meowminder 🐾")
            content.body = Self.message(dayIndex: calendar.ordinality(of: .day, in: .era, for: date) ?? index,
                                        streak: index == 0 ? streak : 0)
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: ids[index], content: content, trigger: trigger))
        }
    }

    private static func message(dayIndex: Int, streak: Int) -> String {
        if streak > 0 {
            return String(localized: "Don't break your \(streak)-day streak! Today's puzzle is waiting.")
        }
        let messages = [
            String(localized: "The cats have a new puzzle ready for you."),
            String(localized: "Today's Daily Puzzle is waiting. Can you get 4 stars?"),
            String(localized: "A few minutes of logic, a lot of cats. Ready to play?"),
            String(localized: "A new cat card could be one puzzle away!"),
        ]
        return messages[((dayIndex % messages.count) + messages.count) % messages.count]
    }
}

/// Hatırlatma zamanları: bugünkü saat geçmediyse ve bugün oynanmadıysa bugünden başlar,
/// yoksa yarından.
enum ReminderSchedule {
    static func dates(now: Date, hour: Int, minute: Int, playedToday: Bool, days: Int, calendar: Calendar = .current) -> [Date] {
        guard let todayAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return [] }
        let startsToday = !playedToday && todayAt > now
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: startsToday ? offset : offset + 1, to: todayAt)
        }
    }
}
