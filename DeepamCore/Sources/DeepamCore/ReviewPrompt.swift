import Foundation

/// Когда просить оценку в App Store.
///
/// Окно — системное (`requestReview`). Своё «Нравится Deepam?» перед ним
/// правило 5.6.1 запрещает, а показать окно или промолчать решает iOS: не
/// больше трёх раз в год, и в TestFlight — никогда. Здесь только наш отбор
/// момента: человек прижился — открывает приложение третий разный день, и
/// хотя бы один виджет стоит, — а в этой версии и последние 90 дней мы ещё не
/// спрашивали.
///
/// Без оценок английские магазины не берутся: у соседей по выдаче на запросы
/// про стих дня тысячи отзывов.
public struct ReviewPrompt: Codable, Equatable, Sendable {
    /// С какого по счёту дня открытий спрашивать. Третий: в первый день
    /// человек ещё настраивает, во второй проверяет, что виджет на месте.
    public static let minOpenDays = 3
    /// Не чаще раза в 90 дней, даже если версии выходят чаще.
    public static let cooldown: TimeInterval = 90 * 86_400

    /// Страница отзыва — для строки «Оценить Deepam» на «Виде». Она
    /// открывается всегда, в отличие от системного окна.
    public static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id6832716134?action=write-review")!

    /// Сколько разных дней приложение открывали.
    public private(set) var openDays = 0
    /// Номер последнего засчитанного дня — `VerseEngine.dayIndex`.
    public private(set) var lastOpenDay: Int?
    /// Версия, в которой спросили в последний раз.
    public private(set) var askedVersion: String?
    public private(set) var askedAt: Date?

    public init() {}

    /// Засчитать открытие. Второе открытие в тот же день не считается.
    public mutating func recordOpen(day: Int) {
        guard day != lastOpenDay else { return }
        openDays += 1
        lastOpenDay = day
    }

    /// Пора ли спросить. Решает только «прижился ли и не спрашивали ли»:
    /// не мешает ли окно тому, что сейчас на экране, проверяет вызывающий.
    public func isDue(widgetCount: Int, version: String, now: Date) -> Bool {
        guard openDays >= Self.minOpenDays, widgetCount > 0, askedVersion != version else { return false }
        guard let askedAt else { return true }
        return now.timeIntervalSince(askedAt) >= Self.cooldown
    }

    public mutating func markAsked(version: String, now: Date) {
        askedVersion = version
        askedAt = now
    }
}
