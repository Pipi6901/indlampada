import Foundation
import Testing
@testable import DeepamCore

@Suite("Уведомления: что и когда")
struct RemindersTests {

    /// Календарь с фиксированным поясом: иначе «восемь утра» зависело бы от
    /// того, где запущены тесты.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func plan(now: Date, daily: Bool, widgets: Int?) throws -> [Reminder] {
        ReminderPlan.make(now: now, calendar: calendar,
                          dailyVerseEnabled: daily, dailyVerseMinutes: 8 * 60,
                          widgetCount: widgets,
                          pool: try Corpus.load(.en).cards, l10n: L10n(.en))
    }

    // MARK: - Стих дня

    @Test
    func `стих дня на месяц вперёд в выбранное время`() throws {
        let reminders = try plan(now: date(26, 7), daily: true, widgets: 1)
            .filter { $0.kind == .dailyVerse }

        #expect(reminders.count == ReminderPlan.dailyDays)
        #expect(Set(reminders.map(\.id)).count == reminders.count)
        for reminder in reminders {
            let parts = calendar.dateComponents([.hour, .minute], from: reminder.date)
            #expect(parts.hour == 8 && parts.minute == 0)
        }
        // В семь утра сегодняшние восемь ещё впереди — первый стих сегодня.
        #expect(calendar.component(.day, from: reminders[0].date) == 26)
    }

    @Test
    func `прошедшее время сегодня переносится на завтра`() throws {
        let reminders = try plan(now: date(26, 9), daily: true, widgets: 1)
            .filter { $0.kind == .dailyVerse }
        #expect(calendar.component(.day, from: reminders[0].date) == 27)
        #expect(reminders.count == ReminderPlan.dailyDays)
    }

    /// В уведомлении тот же стих, что на «Сегодня» в этот день.
    @Test
    func `текст стиха совпадает со стихом дня`() throws {
        let pool = try Corpus.load(.en).cards
        let reminder = try #require(try plan(now: date(26, 7), daily: true, widgets: 1).first)
        let engine = VerseEngine(poolCount: pool.count)
        let card = pool[engine.dailyIndex(on: VerseEngine.dayIndex(for: reminder.date))]
        #expect(reminder.title == card.reference)
        #expect(reminder.body == card.notificationBody)
    }

    // MARK: - Возврат

    /// Возврат — только тому, у кого стих нигде не появляется сам.
    @Test
    func `возврат только без виджета и стиха дня`() throws {
        let kinds = { (reminders: [Reminder]) in Set(reminders.map(\.kind)) }
        #expect(kinds(try plan(now: date(26, 14), daily: false, widgets: 0)) == [.comeback3, .comeback7])
        #expect(kinds(try plan(now: date(26, 14), daily: false, widgets: 2)).isEmpty)
        #expect(!kinds(try plan(now: date(26, 14), daily: true, widgets: 0)).contains(.comeback3))
        // Перепись не ответила — молчим, а не зовём человека с виджетом.
        #expect(kinds(try plan(now: date(26, 14), daily: false, widgets: nil)).isEmpty)
    }

    @Test
    func `возврат через три и семь дней в дневное время`() throws {
        let reminders = try plan(now: date(26, 23, 30), daily: false, widgets: 0)
        let three = try #require(reminders.first { $0.kind == .comeback3 })
        let seven = try #require(reminders.first { $0.kind == .comeback7 })
        #expect(calendar.component(.day, from: three.date) == 29)
        #expect(calendar.component(.day, from: seven.date) == 2)
        // Половина двенадцатого ночи — не время звать: сдвиг на вечер того же дня.
        #expect(calendar.component(.hour, from: three.date) == 20)
    }

    @Test
    func `ночь сдвигается на утро, день не трогается`() {
        #expect(calendar.component(.hour, from: ReminderPlan.daytime(date(26, 3), calendar: calendar)) == 9)
        #expect(calendar.component(.hour, from: ReminderPlan.daytime(date(26, 22), calendar: calendar)) == 20)
        #expect(ReminderPlan.daytime(date(26, 14, 10), calendar: calendar) == date(26, 14, 10))
    }

    // MARK: - Вторая поверхность

    @Test
    func `вторую поверхность предлагаем, только когда стоит одна`() {
        let lock = WidgetCensus.Slot(kind: "DeepamVerse", family: "accessoryInline")
        let home = WidgetCensus.Slot(kind: "DeepamVerse", family: "systemMedium")
        #expect(ReminderPlan.SecondSurface.missing(in: [lock]) == .homeScreen)
        #expect(ReminderPlan.SecondSurface.missing(in: [home, home]) == .lockScreen)
        #expect(ReminderPlan.SecondSurface.missing(in: [lock, home]) == nil)
        #expect(ReminderPlan.SecondSurface.missing(in: []) == nil)
    }

    @Test
    func `вторая поверхность — в срок и с инструкцией`() throws {
        let pool = try Corpus.load(.en).cards
        let due = date(27, 15)
        let reminders = ReminderPlan.make(now: date(26, 15), calendar: calendar,
                                          dailyVerseEnabled: true, dailyVerseMinutes: 8 * 60,
                                          widgetCount: 1,
                                          secondSurface: .init(due: due, missing: .homeScreen),
                                          pool: pool, l10n: L10n(.en))
        let second = try #require(reminders.first { $0.kind == .secondSurface })
        #expect(second.date == due)
        #expect(second.surface == .homeScreen)

        // Срок прошёл — уведомление уже было или не застало человека; второй
        // раз не ставим.
        let late = ReminderPlan.make(now: date(28, 15), calendar: calendar,
                                     dailyVerseEnabled: true, dailyVerseMinutes: 8 * 60,
                                     widgetCount: 1,
                                     secondSurface: .init(due: due, missing: .homeScreen),
                                     pool: pool, l10n: L10n(.en))
        #expect(!late.contains { $0.kind == .secondSurface })
    }

    // MARK: - Виджет пропал

    @Test
    func `виджет пропал — через четыре дня`() {
        let reminder = ReminderPlan.widgetGone(now: date(26, 12), calendar: calendar, l10n: L10n(.en))
        #expect(reminder.kind == .widgetGone)
        #expect(calendar.component(.day, from: reminder.date) == 30)
    }

    // MARK: - Идентификаторы

    /// По идентификатору открытие засчитывается нужному виду, а чужие
    /// уведомления пересборка не трогает.
    @Test
    func `вид узнаётся по идентификатору`() throws {
        let daily = try #require(try plan(now: date(26, 7), daily: true, widgets: 1).first)
        #expect(ReminderKind(identifier: daily.id) == .dailyVerse)
        #expect(ReminderKind(identifier: "deepam.comeback_3") == .comeback3)
        #expect(ReminderKind(identifier: "deepam.widget_gone") == .widgetGone)
        #expect(ReminderKind(identifier: "deepam.first_verse") == .firstVerse)
        #expect(ReminderKind(identifier: "someone.else.daily_verse") == nil)
    }
}

@Suite("Отметки поверхностей по факту")
struct SurfaceSyncTests {

    private func makeSettings() throws -> AppSettings {
        AppSettings(store: try #require(UserDefaults(suiteName: "sync.tests." + UUID().uuidString)))
    }

    @Test
    func `виджет на экране блокировки отмечается сам`() throws {
        let settings = try makeSettings()
        settings.syncWidgetSurfaces([.init(kind: "DeepamVerse", family: "accessoryRectangular")])
        #expect(settings.enabledSurfaces == [.lockScreen])
    }

    /// Убрали — кнопка «Поставить» на «Сегодня» возвращается. StandBy и паузу
    /// система не показывает, их отметки не трогаются.
    @Test
    func `убранный виджет снимает отметку, ручные остаются`() throws {
        let settings = try makeSettings()
        settings.markInstalled(.lockScreen)
        settings.markInstalled(.standBy)
        settings.markInstalled(.pauseBeforeFeed)
        settings.syncWidgetSurfaces([.init(kind: "DeepamVerse", family: "systemSmall")])

        #expect(settings.enabledSurfaces == [.homeScreen, .standBy, .pauseBeforeFeed])
        #expect(settings.nextSurface == .lockScreen)
    }

    @Test
    func `стих дня выключен, статистика включена по умолчанию`() throws {
        let settings = try makeSettings()
        #expect(!settings.dailyVerseEnabled)
        #expect(settings.dailyVerseMinutes == 8 * 60)
        #expect(settings.analyticsEnabled)
    }

    @Test
    func `настройки уведомлений и статистики переживают перезапуск`() throws {
        let store = try #require(UserDefaults(suiteName: "sync.tests." + UUID().uuidString))
        let first = AppSettings(store: store)
        first.dailyVerseEnabled = true
        first.dailyVerseMinutes = 21 * 60 + 30
        first.analyticsEnabled = false

        let second = AppSettings(store: store)
        #expect(second.dailyVerseEnabled)
        #expect(second.dailyVerseMinutes == 21 * 60 + 30)
        #expect(!second.analyticsEnabled)
    }
}
