#if os(iOS)
import DeepamCore
import SwiftUI
import WidgetKit

/// Запись расписания: один день — один стих.
public struct VerseEntry: TimelineEntry, Sendable {
    public let date: Date
    /// Основной текст: перевод (или сам оригинал, если перевода нет).
    public let text: String
    /// Оригинал на санскрите над переводом. `nil`, когда его не показываем: он
    /// выключен в «Виде» или `text` и есть оригинал.
    public let original: String?
    public let reference: String
    public let style: VerseStyle
    /// Выбранный фон-изображение. `nil` — обычная цветная заливка.
    public let scene: VerseScene?
    /// Настройки экрана блокировки: там места на три строки, и «показать
    /// начало» против «уместить всё» — разные виджеты, а не оттенок одного.
    public let lockLength: VerseLength
    public let lockAlignment: VerseAlignment
    /// Начертания и выравнивание по областям: экран блокировки и рабочий стол
    /// настраиваются порознь, а лента у виджета одна на все семейства.
    public let lockFont: VerseFont
    public let widgetAlignment: VerseAlignment
    public let widgetFont: VerseFont
    /// Действует ли Pro на дату записи. От него зависит StandBy: без подписки
    /// он закрыт, остальные поверхности бесплатны.
    public let isPro: Bool

    /// Текст, урезанный по смыслу для экрана блокировки.
    public var shortText: String { Card.shorten(text) }

    public init(date: Date, text: String, original: String? = nil, reference: String,
                style: VerseStyle, scene: VerseScene? = nil,
                lockLength: VerseLength = .full,
                lockAlignment: VerseAlignment = .leading,
                lockFont: VerseFont = .literata,
                widgetAlignment: VerseAlignment = .leading,
                widgetFont: VerseFont = .literata,
                isPro: Bool = true) {
        self.date = date
        self.text = text
        self.original = original
        self.reference = reference
        self.style = style
        self.scene = scene
        self.lockLength = lockLength
        self.lockAlignment = lockAlignment
        self.lockFont = lockFont
        self.widgetAlignment = widgetAlignment
        self.widgetFont = widgetFont
        self.isPro = isPro
    }
}

/// Карточка дня по настройкам человека.
///
/// Вынесена из поставщика, потому что её спрашивают двое: расписание виджета и
/// кнопка в Пункте управления. Держать две копии одного отбора значило бы
/// однажды получить в кнопке не тот стих, что на экране блокировки.
func dailyCard(for date: Date) -> Card? {
    let settings = AppSettings()
    let locale = settings.language ?? .detect()
    // Корпус лежит в ресурсах пакета, а не в бандле расширения:
    // приложение и виджет линкуют один и тот же DeepamCore.
    guard let corpus = try? Corpus.load(locale) else { return nil }

    let pool = corpus.cards(themes: settings.themes)
    guard !pool.isEmpty else { return nil }

    let engine = VerseEngine(poolCount: pool.count)
    return pool[engine.dailyIndex(on: VerseEngine.dayIndex(for: date))]
}

/// Поставщик расписания для всех виджетов.
///
/// Расписание строится на четырнадцать дней вперёд одной записью в сутки на
/// полночь: стих меняется ровно в полночь, а не «когда-нибудь после», даже
/// если система задержит следующий запрос. Сам запрос — каждую ночь, ради
/// отсрочки уведомления «стих пропал с экрана?».
public struct VerseProvider: TimelineProvider {
    private let daysAhead = 14

    public init() {}

    /// Заглушка на время, пока система рисует каркас виджета. Стих берётся из
    /// того же издания, что и настоящий: русский текст в английской сборке
    /// мелькал бы при каждой перерисовке.
    public func placeholder(in context: Context) -> VerseEntry {
        let locale = AppSettings().language ?? .detect()
        let l10n = L10n(locale)
        return VerseEntry(date: .now,
                          text: l10n[.demoVerse],
                          reference: l10n[.demoReference],
                          style: .ink)
    }

    public func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entry(for: .now) ?? placeholder(in: context))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        // Виджет жив — «стих пропал с экрана?» отодвигается ещё на четыре дня.
        // Перестанет система спрашивать расписание — значит, виджет убрали, и
        // уведомление сработает само. Разрешения нет — система его молча не
        // примет, и это правильно.
        Reminders.postponeWidgetGone(l10n: L10n(AppSettings().language ?? .detect()))
        WidgetPulse.beat(family: context.family.description)

        let calendar = Calendar.current
        var entries: [VerseEntry] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now),
                  let entry = entry(for: offset == 0 ? .now : calendar.startOfDay(for: day))
            else { continue }
            entries.append(entry)
        }
        // Отменённая подписка кончается посреди дня, а записи стоят на полночь.
        // Без отдельной точки на момент конца StandBy оставался бы открытым и
        // платное оформление держалось бы до следующей полуночи.
        if let status = AppSettings().proStatus, status.isActive, !status.willRenew,
           let end = status.expiresAt, end > .now,
           let last = entries.last?.date, end < last,
           let atEnd = entry(for: end) {
            entries.append(atEnd)
            entries.sort { $0.date < $1.date }
        }
        // Новое расписание просим каждую ночь, хотя записей на две недели: по
        // этим запросам живёт отсрочка «стих пропал с экрана?» выше. Раз в
        // сутки — копейки из бюджета обновлений, а если система запрос
        // отложит, виджет всё равно покажет верный стих из запаса. Явная дата
        // надёжнее `.atEnd`: та зависит от того, когда виджет в последний раз
        // рисовали.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        completion(Timeline(entries: entries, policy: .after(calendar.startOfDay(for: tomorrow))))
    }

    /// Виджет всегда показывает стих дня и никогда — пролистанный.
    ///
    /// Это не упрощение, а обещание продукта: на поверхностях живёт сегодняшнее
    /// слово, и если бы туда уезжало то, что человек листнул в приложении,
    /// смысл «стиха дня» пропал бы. Поэтому смещение здесь не читается вовсе.
    ///
    /// Оформление берётся с поправкой на подписку в момент записи: приложение
    /// снимает платное само, но только когда его откроют, а виджет должен
    /// отпустить платное в срок и без этого.
    private func entry(for date: Date) -> VerseEntry? {
        let settings = AppSettings()
        guard let card = dailyCard(for: date) else { return nil }
        // Тот же отбор, что на экране «Сегодня»: оригинал над переводом, если он включён.
        let parts = card.parts(locale: settings.language ?? .detect(),
                               showsOriginal: settings.showsOriginal)
        return VerseEntry(date: date,
                          text: parts.translation ?? parts.original ?? card.text,
                          original: parts.translation == nil ? nil : parts.original,
                          reference: card.reference,
                          style: settings.effectiveStyle(for: .widgets, at: date),
                          scene: settings.effectiveScene(for: .widgets, at: date),
                          lockLength: settings.lockLength,
                          lockAlignment: settings.alignment(for: .lockScreen),
                          lockFont: settings.effectiveFont(for: .lockScreen, at: date),
                          widgetAlignment: settings.alignment(for: .widgets),
                          widgetFont: settings.effectiveFont(for: .widgets, at: date),
                          isPro: settings.allowsPro(at: date))
    }
}
#endif
