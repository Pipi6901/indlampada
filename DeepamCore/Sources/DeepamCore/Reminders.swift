import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Какое уведомление. Строка идёт и в идентификатор, и в аналитику.
public enum ReminderKind: String, Sendable, CaseIterable {
    /// Стих дня в выбранное время.
    case dailyVerse = "daily_verse"
    /// Возврат после трёх и семи дней тишины.
    case comeback3 = "comeback_3"
    case comeback7 = "comeback_7"
    /// Виджет давно не обновлялся — похоже, его убрали.
    case widgetGone = "widget_gone"
    /// Стоит одна поверхность — предложить вторую.
    case secondSurface = "second_surface"
    /// Первый стих — в онбординге, через пару секунд после разрешения.
    case firstVerse = "first_verse"

    /// Свои уведомления узнаются по префиксу: так пересборка не трогает чужие,
    /// а открытие засчитывается нужному виду.
    static let prefix = "deepam."

    /// Вид по идентификатору уведомления. `nil` — уведомление не наше.
    public init?(identifier: String) {
        guard identifier.hasPrefix(Self.prefix) else { return nil }
        let rest = identifier.dropFirst(Self.prefix.count)
        let raw = rest.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
        self.init(rawValue: raw)
    }
}

/// Одно запланированное уведомление — ещё без системы, чтобы план можно было
/// проверить тестом.
public struct Reminder: Sendable, Equatable {
    public let id: String
    public let kind: ReminderKind
    public let date: Date
    public let title: String
    public let body: String
    /// Какую инструкцию открыть по тапу. `nil` — просто открыть приложение.
    public var surface: Surface? = nil

    /// Ключ поверхности в `userInfo` уведомления.
    public static let surfaceKey = "surface"
}

/// Ответ системы на вопрос об уведомлениях.
public enum NotificationAuthorization: Sendable, Equatable {
    case notAsked
    case allowed
    case denied
}

/// Что и когда прислать.
///
/// Уведомления локальные: бэкенда нет, всё планируется на устройстве. iOS
/// держит не больше 64 отложенных уведомлений на приложение, поэтому стих дня
/// ставится на месяц вперёд, а очередь пересобирается при каждом выходе
/// приложения на передний план. Человек, который месяц приложение не открывал,
/// получит месяц стихов — дальше очередь кончится.
public enum ReminderPlan {
    /// На сколько дней вперёд ставить стих дня. 30 плюс два возврата и
    /// «виджет пропал» — 33 из 64 доступных.
    public static let dailyDays = 30

    /// Сколько виджет может молчать, прежде чем спросить, не убрали ли его.
    /// Виджет просит обновление каждую ночь; четыре дня — запас на случай,
    /// если система отложит пару обновлений.
    public static let widgetSilence: TimeInterval = 4 * 86_400

    public static func make(now: Date,
                            calendar: Calendar = .current,
                            dailyVerseEnabled: Bool,
                            dailyVerseMinutes: Int,
                            widgetCount: Int?,
                            secondSurface: SecondSurface? = nil,
                            pool: [Card],
                            l10n: L10n) -> [Reminder] {
        var reminders: [Reminder] = []

        if dailyVerseEnabled, !pool.isEmpty {
            // Тот же стих, что на «Сегодня» и в виджете в этот день: тот же
            // пул по темам и тот же движок.
            let engine = VerseEngine(poolCount: pool.count)
            let today = calendar.startOfDay(for: now)
            for offset in 0...dailyDays {
                guard reminders.count < dailyDays,
                      let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let fire = calendar.date(byAdding: .minute, value: dailyVerseMinutes, to: day),
                      fire > now
                else { continue }
                let card = pool[engine.dailyIndex(on: VerseEngine.dayIndex(for: fire))]
                reminders.append(Reminder(
                    id: ReminderKind.prefix + ReminderKind.dailyVerse.rawValue + ".\(Int(fire.timeIntervalSince1970))",
                    kind: .dailyVerse,
                    date: fire,
                    title: card.reference,
                    body: card.notificationBody
                ))
            }
        }

        // Возврат — только тем, у кого стих сам нигде не появляется: ни
        // виджета, ни стиха дня. Остальных звать незачем, у них продукт и так
        // работает каждый день. Неизвестное число виджетов — не ноль: перепись
        // могла не ответить, и звать «вернись» человека с виджетом хуже, чем
        // промолчать.
        if !dailyVerseEnabled, widgetCount == 0 {
            let comebacks: [(ReminderKind, Int, L10n.Key, L10n.Key)] = [
                (.comeback3, 3, .comeback3Title, .comeback3Body),
                (.comeback7, 7, .comeback7Title, .comeback7Body),
            ]
            for (kind, days, title, body) in comebacks {
                let fire = daytime(now.addingTimeInterval(TimeInterval(days) * 86_400), calendar: calendar)
                // Неделя тишины зовёт поставить стих на экран блокировки —
                // тап сразу открывает инструкцию.
                reminders.append(Reminder(id: ReminderKind.prefix + kind.rawValue,
                                          kind: kind, date: fire,
                                          title: l10n[title], body: l10n[body],
                                          surface: kind == .comeback7 ? .lockScreen : nil))
            }
        }

        if let secondSurface, secondSurface.due > now {
            let (title, body): (L10n.Key, L10n.Key) = secondSurface.missing == .homeScreen
                ? (.secondHomeTitle, .secondHomeBody)
                : (.secondLockTitle, .secondLockBody)
            reminders.append(Reminder(id: ReminderKind.prefix + ReminderKind.secondSurface.rawValue,
                                      kind: .secondSurface,
                                      date: daytime(secondSurface.due, calendar: calendar),
                                      title: l10n[title], body: l10n[body],
                                      surface: secondSurface.missing))
        }

        return reminders
    }

    /// Вторая поверхность: когда и какую предложить.
    public struct SecondSurface: Sendable, Equatable {
        public let due: Date
        public let missing: Surface

        public init(due: Date, missing: Surface) {
            self.due = due
            self.missing = missing
        }

        /// Из переписи: ровно одна из двух видимых поверхностей — предлагаем
        /// другую. Ни одной или обе — предлагать нечего.
        public static func missing(in slots: [WidgetCensus.Slot]) -> Surface? {
            let present = Set(slots.compactMap(\.surface))
            guard present.count == 1 else { return nil }
            return present.contains(.lockScreen) ? .homeScreen : .lockScreen
        }
    }

    /// «Стих пропал с экрана?» — через четыре дня тишины виджета.
    public static func widgetGone(now: Date, calendar: Calendar = .current, l10n: L10n) -> Reminder {
        Reminder(id: ReminderKind.prefix + ReminderKind.widgetGone.rawValue,
                 kind: .widgetGone,
                 date: daytime(now.addingTimeInterval(widgetSilence), calendar: calendar),
                 title: l10n[.widgetGoneTitle],
                 body: l10n[.widgetGoneBody],
                 surface: .lockScreen)
    }

    /// Сдвигает время в дневные часы: возврат в три ночи будит, а не зовёт.
    static func daytime(_ date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        let target = hour < 9 ? 9 : (hour >= 21 ? 20 : nil)
        guard let target else { return date }
        return calendar.date(bySettingHour: target, minute: 0, second: 0, of: date) ?? date
    }
}

#if canImport(UserNotifications)
/// Работа с системой уведомлений.
///
/// Только обратные вызовы и простые значения: объекты фреймворка не помечены
/// как безопасные для передачи между потоками, и держать их через `await` в
/// Swift 6 значит спорить с компилятором. Центр берётся заново в каждом
/// вызове, а не захватывается замыканием.
public enum Reminders {
    /// Разрешение на уведомления. Системный запрос показывается один раз;
    /// дальше ответ приходит сразу, без вопроса.
    public static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Что система ответила про уведомления. В отличие от `isAuthorized`,
    /// отличает «ещё не спрашивали» от «отказали»: переспросить можно только
    /// первых — второй раз iOS окно не покажет.
    public static func authorization() async -> NotificationAuthorization {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let answer: NotificationAuthorization = switch settings.authorizationStatus {
                case .notDetermined: .notAsked
                case .denied: .denied
                default: .allowed
                }
                continuation.resume(returning: answer)
            }
        }
    }

    /// Разрешены ли уведомления сейчас. Человек мог выключить их в настройках
    /// iPhone в любой момент.
    public static func isAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let status = settings.authorizationStatus
                continuation.resume(returning: status == .authorized || status == .provisional)
            }
        }
    }

    /// Ставит план приложения взамен прежнего.
    ///
    /// Снимаются только свои уведомления, которых нет в новом плане; те, что
    /// есть, перезаписываются по тому же идентификатору. «Виджет пропал» не
    /// трогается — его ведёт сам виджет.
    public static func replace(with reminders: [Reminder]) {
        let keep = Set(reminders.map(\.id))
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { id in
                guard let kind = ReminderKind(identifier: id),
                      kind != .widgetGone, kind != .firstVerse else { return false }
                return !keep.contains(id)
            }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for reminder in reminders { center.add(request(for: reminder)) }
        }
    }

    /// Первый стих — прямо сейчас, через две секунды.
    ///
    /// Шаг онбординга «Прислать первый стих»: человек видит настоящий баннер,
    /// не выходя из приложения (`willPresent` показывает его и при открытом).
    /// Две секунды — чтобы системное окно разрешения успело уйти и баннер не
    /// пришёл под ним. Пересборка очереди его не снимает: включение стиха дня
    /// пересобирает её в эти же секунды.
    public static func sendFirstVerse(_ card: Card) {
        let content = UNMutableNotificationContent()
        content.title = card.reference
        content.body = card.notificationBody
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: ReminderKind.prefix + ReminderKind.firstVerse.rawValue,
            content: content, trigger: trigger))
    }

    /// Виджет жив — «пропал» отодвигается ещё на четыре дня. Зовут и виджет при
    /// каждом построении расписания, и приложение, когда видит виджеты.
    public static func postponeWidgetGone(l10n: L10n, now: Date = .now) {
        UNUserNotificationCenter.current().add(request(for: ReminderPlan.widgetGone(now: now, l10n: l10n)))
    }

    /// Виджетов нет, и человек сейчас в приложении — кнопка «Поставить» на
    /// «Сегодня» скажет то же самое без уведомления.
    public static func cancelWidgetGone() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ReminderKind.prefix + ReminderKind.widgetGone.rawValue])
    }

    private static func request(for reminder: Reminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        if let surface = reminder.surface { content.userInfo = [Reminder.surfaceKey: surface.rawValue] }
        // Дата раскладывается по местному календарю: «в восемь утра» должно
        // остаться восемью утра и после перелёта.
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }
}
#endif
