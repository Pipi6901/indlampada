import Foundation
import Testing
@testable import DeepamCore

@Suite("Просьба об оценке")
struct ReviewPromptTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Три открытия в разные дни — столько и нужно.
    private func settled() -> ReviewPrompt {
        var review = ReviewPrompt()
        for day in 100...102 { review.recordOpen(day: day) }
        return review
    }

    /// Пять открытий за утро — один день: прижился не тот, кто открыл часто,
    /// а тот, кто возвращается.
    @Test
    func `открытия в один день считаются одним`() {
        var review = ReviewPrompt()
        for _ in 0..<5 { review.recordOpen(day: 100) }
        review.recordOpen(day: 101)
        #expect(review.openDays == 2)
        #expect(!review.isDue(widgetCount: 1, version: "1.0.2", now: now))
    }

    @Test
    func `третий день с виджетом — пора`() {
        #expect(settled().isDue(widgetCount: 1, version: "1.0.2", now: now))
    }

    /// Без виджета приложение ещё не дало главного — и оценка была бы за
    /// обещание, а не за стих на экране.
    @Test
    func `без виджета не спрашиваем`() {
        #expect(!settled().isDue(widgetCount: 0, version: "1.0.2", now: now))
    }

    @Test
    func `в той же версии второй раз не спрашиваем`() {
        var review = settled()
        review.markAsked(version: "1.0.2", now: now)
        #expect(!review.isDue(widgetCount: 1, version: "1.0.2", now: now.addingTimeInterval(400 * 86_400)))
    }

    /// Новая версия через месяц — ещё рано: интервал держится, даже если
    /// версии выходят часто.
    @Test
    func `новая версия ждёт 90 дней`() {
        var review = settled()
        review.markAsked(version: "1.0.2", now: now)
        #expect(!review.isDue(widgetCount: 1, version: "1.0.3", now: now.addingTimeInterval(30 * 86_400)))
        #expect(review.isDue(widgetCount: 1, version: "1.0.3", now: now.addingTimeInterval(90 * 86_400)))
    }

    /// Счёт дней переживает перезапуск: он живёт в общей группе, а не в памяти.
    @Test
    func `счёт сохраняется в настройках`() throws {
        let name = "test.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        let settings = AppSettings(store: store)
        settings.review.recordOpen(day: 100)
        settings.review.markAsked(version: "1.0.2", now: now)

        let reread = AppSettings(store: store)
        #expect(reread.review == settings.review)
        #expect(reread.review.openDays == 1)
        #expect(reread.review.askedVersion == "1.0.2")
    }
}
