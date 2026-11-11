import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
import Observation

/// Настройки приложения.
///
/// Живут в общей группе, а не в личных `UserDefaults`: те же значения читают
/// расширения виджета, и второй копии этих данных быть не должно.
@Observable
public final class AppSettings {
    /// Идентификатор группы. Расширения объявляют его же в своих правах.
    public static let appGroup = "group.com.astonio.deepam"

    private let store: UserDefaults

    /// - Parameter store: хранилище. В тестах передаётся свой экземпляр, чтобы
    ///   они не топтались по настройкам разработчика и друг по другу.
    public init(store: UserDefaults? = nil) {
        self.store = store ?? UserDefaults(suiteName: AppSettings.appGroup) ?? .standard
        self.language = Self.read(self.store, .language).flatMap(AppLocale.init(rawValue:))
        self.themes = Set(self.store.stringArray(forKey: Key.themes.rawValue) ?? [])
        self.goal = Self.read(self.store, .goal).flatMap(OnboardingGoal.init(rawValue:))
        self.hasSeenOnboarding = self.store.bool(forKey: Key.hasSeenOnboarding.rawValue)
        self.appIcon = Self.read(self.store, .appIcon) ?? AppIcon.default.rawValue
        let raw = self.store.stringArray(forKey: Key.surfaces.rawValue) ?? []
        self.enabledSurfaces = Set(raw.compactMap(Surface.init(rawValue:)))
        self.styles = Self.readStyles(self.store)
        self.scenes = Self.readScenes(self.store)
        self.hasSeenCoach = self.store.bool(forKey: Key.hasSeenCoach.rawValue)
        self.fonts = Self.readMap(self.store, .fonts, VerseFont.init(rawValue:))
        self.alignments = Self.readMap(self.store, .alignments, VerseAlignment.init(rawValue:))
        self.widgetSize = Self.read(self.store, .widgetSize)
            .flatMap(WidgetSize.init(rawValue:)) ?? .medium
        self.lockLength = Self.read(self.store, .lockLength)
            .flatMap(VerseLength.init(rawValue:)) ?? .full
        self.proStatus = Self.readProStatus(self.store)
        self.dailyVerseEnabled = self.store.bool(forKey: Key.dailyVerse.rawValue)
        self.dailyVerseMinutes = self.store.object(forKey: Key.dailyVerseMinutes.rawValue) as? Int
            ?? Self.defaultDailyVerseMinutes
        // Хранится выключение, а не включение: у нового человека ключа нет, и
        // `bool(forKey:)` даёт `false` — то есть статистика включена.
        self.analyticsEnabled = !self.store.bool(forKey: Key.analyticsOff.rawValue)
        self.cancelReasonAsked = self.store.bool(forKey: Key.cancelReasonAsked.rawValue)
        self.welcomeOfferShown = self.store.bool(forKey: Key.welcomeOfferShown.rawValue)
        self.secondSurfaceDue = self.store.object(forKey: Key.secondSurfaceDue.rawValue) as? Date
        self.analyticsInstanceID = self.store.string(forKey: Key.analyticsInstanceID.rawValue)
        self.analyticsAppID = self.store.string(forKey: Key.analyticsAppID.rawValue)
        self.lastPulseDay = self.store.object(forKey: Key.lastPulseDay.rawValue) as? Int
        self.review = Self.readReview(self.store)
        self.whatsNewSeen = self.store.string(forKey: Key.whatsNewSeen.rawValue)
        self.promoOptIn = self.store.bool(forKey: Key.promoOptIn.rawValue)
        // Ключа у нового человека нет — оригинал на санскрите по умолчанию выключен: включается в «Виде».
        self.showsOriginal = self.store.object(forKey: Key.showsOriginal.rawValue) as? Bool ?? false
    }

    // MARK: - Значения

    /// Язык корпуса. `nil` — брать язык устройства.
    public var language: AppLocale? {
        didSet { write(.language, language?.rawValue); reloadWidgets() }
    }

    /// Показывать ли оригинал на санскрите над переводом. По умолчанию нет (решение куратора):
    /// человек включает его сам на «Виде». Если основной текст сам
    /// написан оригиналом (языка с таким текстом пока нет), выключатель не действует.
    public var showsOriginal: Bool {
        didSet { store.set(showsOriginal, forKey: Key.showsOriginal.rawValue); reloadWidgets() }
    }

    /// Темы состояний, по которым сужен пул. Пустой набор — весь корпус.
    ///
    /// Набор, а не одна тема: в онбординге человек отмечает несколько, и
    /// сужать пул до одного состояния было бы слишком узко — на «бессоннице»
    /// осталось бы одиннадцать карточек.
    public var themes: Set<String> {
        didSet { store.set(themes.sorted(), forKey: Key.themes.rawValue); reloadWidgets() }
    }

    /// Ответ на «Что тебе сейчас нужнее?». На выдачу стихов не влияет — по
    /// нему пейволл выбирает заголовок и порядок плиток, и не только в конце
    /// онбординга, но и позже, с замков. Виджеты не трогаем: перерисовывать их
    /// из-за ответа, который они не показывают, незачем.
    public var goal: OnboardingGoal? {
        didSet { write(.goal, goal?.rawValue) }
    }

    public var hasSeenOnboarding: Bool {
        didSet { store.set(hasSeenOnboarding, forKey: Key.hasSeenOnboarding.rawValue) }
    }

    /// Пройден ли обучающий тур. Показывается один раз: подсветка поверх
    /// экрана, который человек уже знает, только мешает.
    public var hasSeenCoach: Bool {
        didSet { store.set(hasSeenCoach, forKey: Key.hasSeenCoach.rawValue) }
    }

    /// Стих дня уведомлением. Включается только вместе с разрешением системы:
    /// без него флаг ничего бы не значил.
    public var dailyVerseEnabled: Bool {
        didSet { store.set(dailyVerseEnabled, forKey: Key.dailyVerse.rawValue) }
    }

    /// Время стиха дня — минуты от полуночи по местному времени. Числом, а не
    /// датой: часовой пояс может смениться, а «в восемь утра» должно остаться
    /// восемью утра.
    public var dailyVerseMinutes: Int {
        didSet { store.set(dailyVerseMinutes, forKey: Key.dailyVerseMinutes.rawValue) }
    }

    /// Восемь утра: до работы, но уже не во сне.
    public static let defaultDailyVerseMinutes = 8 * 60

    /// Версия, чей экран «Что нового» уже показан. Новые пользователи получают
    /// её отметку в конце онбординга: всё новое им показал он сам.
    public var whatsNewSeen: String? {
        didSet { write(.whatsNewSeen, whatsNewSeen) }
    }

    /// Согласие на «Новости и обновления» — рекламные рассылки: новинки,
    /// акции, скидки. По правилу App Store 4.5.4 такие пуши можно слать только
    /// тем, кто отдельно согласился в самом приложении, поэтому по умолчанию
    /// выключено. Разрешение на уведомления для стиха дня согласием не считается.
    public var promoOptIn: Bool {
        didSet { store.set(promoOptIn, forKey: Key.promoOptIn.rawValue) }
    }

    /// Анонимная статистика — переключатель на «Виде». По умолчанию включена.
    public var analyticsEnabled: Bool {
        didSet { store.set(!analyticsEnabled, forKey: Key.analyticsOff.rawValue) }
    }

    /// Лист «почему отменил?» уже показывали. Один раз за установку: второй
    /// вопрос о том же — уже назойливость.
    public var cancelReasonAsked: Bool {
        didSet { store.set(cancelReasonAsked, forKey: Key.cancelReasonAsked.rawValue) }
    }

    /// Скидку после закрытого пейволла уже предлагали. Тоже один раз.
    public var welcomeOfferShown: Bool {
        didSet { store.set(welcomeOfferShown, forKey: Key.welcomeOfferShown.rawValue) }
    }

    /// Когда напомнить про вторую поверхность. Ставится один раз — в момент,
    /// когда перепись впервые видит ровно одну, — и дальше не сдвигается:
    /// иначе тот, кто открывает приложение каждый день, не получил бы его
    /// никогда.
    public var secondSurfaceDue: Date? {
        didSet { store.set(secondSurfaceDue, forKey: Key.secondSurfaceDue.rawValue) }
    }

    /// Идентификатор установки в Firebase. Его пишет приложение, а читает
    /// виджет: свой «пульс» он шлёт в GA4 от имени той же установки.
    public var analyticsInstanceID: String? {
        didSet { write(.analyticsInstanceID, analyticsInstanceID) }
    }

    /// Идентификатор приложения в Firebase (`GOOGLE_APP_ID`). Его тоже пишет
    /// приложение, а читает виджет: у расширения нет `GoogleService-Info.plist`,
    /// и зашитое в код значение принадлежало бы чужому проекту.
    public var analyticsAppID: String? {
        didSet { write(.analyticsAppID, analyticsAppID) }
    }

    /// День последнего «пульса» виджета — не чаще раза в сутки.
    public var lastPulseDay: Int? {
        didSet { store.set(lastPulseDay, forKey: Key.lastPulseDay.rawValue) }
    }

    /// Счёт дней открытий и когда последний раз просили оценку.
    public var review: ReviewPrompt {
        didSet {
            if let data = try? JSONEncoder().encode(review) { store.set(data, forKey: Key.review.rawValue) }
        }
    }

    /// Поверхности, которые человек отметил поставленными.
    ///
    /// Это отметка, а не факт: узнать снаружи, стоит ли виджет, приложение не
    /// может. Для виджетов отметка ставится сама, когда расширение впервые
    /// попросило данные, — остальное человек отмечает руками.
    public var enabledSurfaces: Set<Surface> {
        didSet { store.set(enabledSurfaces.map(\.rawValue).sorted(), forKey: Key.surfaces.rawValue) }
    }

    public var appIcon: String {
        didSet { write(.appIcon, appIcon) }
    }

    /// Шрифт стиха, размер виджета в предпросмотре и настройки экрана
    /// блокировки. Все четыре живут здесь, а не в состоянии экрана: их читают
    /// и расширения виджета.
    /// Шрифт по областям.
    ///
    /// Был один на всё приложение, и смена его на вкладке «Виджеты» меняла
    /// начертание и на экранах — то есть настройка стояла в одном месте, а
    /// действовала в трёх. Теперь это такой же по-областной выбор, как набор
    /// цветов и фон.
    public private(set) var fonts: [AppearanceArea: VerseFont]

    /// По умолчанию системный: остальные начертания платные, и открываться
    /// приложение обязано тем, что человеку уже принадлежит.
    public func font(for area: AppearanceArea) -> VerseFont {
        fonts[area] ?? .system
    }

    public func setFont(_ font: VerseFont, for area: AppearanceArea) {
        fonts[area] = font
        store.set(fonts.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.fonts.rawValue)
        reloadWidgets()
    }

    /// Выравнивание текста по областям. У виджета на рабочем столе оно тоже
    /// имеет смысл, а не только на экране блокировки.
    public private(set) var alignments: [AppearanceArea: VerseAlignment]

    public func alignment(for area: AppearanceArea) -> VerseAlignment {
        alignments[area] ?? .leading
    }

    public func setAlignment(_ value: VerseAlignment, for area: AppearanceArea) {
        alignments[area] = value
        store.set(alignments.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.alignments.rawValue)
        reloadWidgets()
    }

    public var widgetSize: WidgetSize {
        didSet { write(.widgetSize, widgetSize.rawValue) }
    }

    public var lockLength: VerseLength {
        didSet { write(.lockLength, lockLength.rawValue) }
    }

    /// Выбранный набор стилей по областям.
    public private(set) var styles: [AppearanceArea: VerseStyle]

    public func style(for area: AppearanceArea) -> VerseStyle {
        styles[area] ?? .night
    }

    public func setStyle(_ style: VerseStyle, for area: AppearanceArea) {
        styles[area] = style
        reloadWidgets()
        // Цвет и картинка — один и тот же выбор, сделанный по-разному. Выбрал
        // цвет — картинка снимается, иначе она осталась бы поверх и выбор
        // выглядел бы не сработавшим.
        setScene(nil, for: area)
        store.set(styles.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.styles.rawValue)
    }

    /// Выбранный фон-изображение по областям. `nil` — обычный цветной набор.
    public private(set) var scenes: [AppearanceArea: VerseScene]

    public func scene(for area: AppearanceArea) -> VerseScene? {
        scenes[area]
    }

    public func setScene(_ scene: VerseScene?, for area: AppearanceArea) {
        scenes[area] = scene
        reloadWidgets()
        store.set(scenes.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.scenes.rawValue)
    }

    // MARK: - Подписка

    /// Последнее, что приложение узнало о подписке.
    ///
    /// Пишет только приложение — у него есть RevenueCat. Читают оба: приложение
    /// решает по нему откат, виджет — что рисовать. `nil` значит, что с этой
    /// версии приложение ещё не запускалось и статуса не знает.
    public private(set) var proStatus: ProStatus?

    /// Запоминает свежий снимок и, если он изменился, перерисовывает виджеты:
    /// конец подписки должен дойти до StandBy, не дожидаясь полуночи.
    public func updateProStatus(_ status: ProStatus) {
        guard status != proStatus else { return }
        proStatus = status
        if let data = try? JSONEncoder().encode(status) {
            store.set(data, forKey: Key.proStatus.rawValue)
        }
        reloadWidgets()
    }

    /// Действует ли Pro в момент `date` — для того, кто RevenueCat не видит.
    ///
    /// Неизвестный статус трактуем в пользу человека. Бывает он ровно в одном
    /// случае: виджет обновился вместе с приложением, а само приложение с тех
    /// пор не открывали. Платное к этому моменту можно было выбрать только по
    /// подписке, и отнимать его по незнанию — значит ударить по своему же
    /// подписчику. После первого запуска статус известен.
    public func allowsPro(at date: Date) -> Bool {
        proStatus?.grants(at: date) ?? true
    }

    /// Набор с поправкой на подписку в момент `date`.
    ///
    /// Этим и двумя соседними методами рисует виджет. Приложение откатывает
    /// выбор само, но до виджета откат доходит, только когда приложение
    /// откроют, — а подписка кончается и без этого.
    public func effectiveStyle(for area: AppearanceArea, at date: Date) -> VerseStyle {
        let chosen = self.style(for: area)
        return allowsPro(at: date) ? chosen : chosen.freeEquivalent
    }

    public func effectiveScene(for area: AppearanceArea, at date: Date) -> VerseScene? {
        guard let chosen = self.scene(for: area) else { return nil }
        return allowsPro(at: date) || !chosen.isPremium ? chosen : nil
    }

    public func effectiveFont(for area: AppearanceArea, at date: Date) -> VerseFont {
        let chosen = self.font(for: area)
        return allowsPro(at: date) || !chosen.isPremium ? chosen : .system
    }

    /// Снимает платное оформление, когда подписка кончилась.
    ///
    /// Без этого отменённый триал работал как бесплатный ключ: за неделю
    /// человек расставлял себе платные фоны, шрифты и иконку, отменял — и
    /// пользовался ими дальше. Замки стояли только на выборе, а показ уже
    /// выбранного ничего не проверял.
    ///
    /// Снимается только платное и только на ближайшее бесплатное: бесплатный
    /// фон и шрифт остаются как были, светлый набор уходит в светлый.
    /// Возвращает, менялось ли что-нибудь, — по этому решается, говорить ли
    /// человеку.
    @discardableResult
    public func dropPremiumAppearance() -> Bool {
        var changed = false
        for (area, chosen) in scenes where chosen.isPremium {
            scenes[area] = nil
            changed = true
        }
        for (area, chosen) in styles where chosen.isPremium {
            styles[area] = chosen.freeEquivalent
            changed = true
        }
        for (area, chosen) in fonts where chosen.isPremium {
            fonts[area] = nil
            changed = true
        }
        if AppIcon(rawValue: appIcon)?.isPremium == true {
            appIcon = AppIcon.default.rawValue
            changed = true
        }
        guard changed else { return false }
        persistAppearance()
        reloadWidgets()
        return true
    }

    // MARK: - Производное

    /// Ни одной поверхности — экран «Сегодня» показывает приглашение поставить
    /// первую. Это состояние 07 из макета.
    public var hasNoSurfaces: Bool { enabledSurfaces.isEmpty }

    /// Всё поставлено — приглашение убирается совсем (состояние 07b).
    ///
    /// Считаем по `shipped`, а не по всем случаям: недостижимую поверхность
    /// нельзя поставить, и по `allCases` состояние «всё готово» не наступало бы
    /// никогда.
    public var hasAllSurfaces: Bool {
        Surface.shipped.allSatisfy(enabledSurfaces.contains)
    }

    /// Какую поверхность предложить следующей.
    ///
    /// Ведёт к ближайшей непоставленной в порядке объявления, а не к случайной:
    /// порядок в `Surface.allCases` идёт от самого простого к самому сложному.
    public var nextSurface: Surface? {
        Surface.shipped.first { !enabledSurfaces.contains($0) }
    }

    public func markInstalled(_ surface: Surface) {
        enabledSurfaces.insert(surface)
    }

    public func markRemoved(_ surface: Surface) {
        enabledSurfaces.remove(surface)
    }

    /// Сверяет отметки с тем, что реально стоит на экранах.
    ///
    /// Касается только экрана блокировки и рабочего стола — их видно по
    /// переписи виджетов. StandBy, пункт управления и паузу система приложению
    /// не показывает, их отметки остаются ручными. Убрали виджет — отметка
    /// снимается, и на «Сегодня» снова появляется кнопка «Поставить».
    public func syncWidgetSurfaces(_ slots: [WidgetCensus.Slot]) {
        var surfaces = enabledSurfaces
        for surface in [Surface.lockScreen, .homeScreen] {
            if slots.contains(where: { $0.surface == surface }) {
                surfaces.insert(surface)
            } else {
                surfaces.remove(surface)
            }
        }
        // Присваивание пишет в хранилище — без изменений писать незачем.
        if surfaces != enabledSurfaces { enabledSurfaces = surfaces }
    }

    // MARK: - Хранилище

    /// Просит систему перерисовать виджеты.
    ///
    /// Без этого настройка менялась в приложении, а виджет на рабочем столе
    /// оставался прежним до следующей точки своего расписания — то есть до
    /// полуночи. Человек меняет набор, смотрит на экран «Домой» и видит старый.
    ///
    /// Расширение читает те же настройки из общей группы, поэтому перезагрузки
    /// ленты достаточно: передавать ничего не нужно.
    func reloadWidgets() {
        #if canImport(WidgetKit) && !os(macOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private enum Key: String {
        case language, themes, hasSeenOnboarding, hasSeenCoach, surfaces, styles, scenes, appIcon
        case fonts, widgetSize, lockLength, alignments, goal, proStatus
        case dailyVerse, dailyVerseMinutes, analyticsOff
        case cancelReasonAsked, welcomeOfferShown, secondSurfaceDue
        case analyticsInstanceID, analyticsAppID, lastPulseDay, review
        case whatsNewSeen, promoOptIn, showsOriginal
    }

    /// Пишет наборы, фоны и шрифты разом: откат меняет их вместе, и
    /// сохранять по одному значило бы трижды дёрнуть хранилище.
    private func persistAppearance() {
        store.set(styles.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.styles.rawValue)
        store.set(scenes.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.scenes.rawValue)
        store.set(fonts.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value.rawValue },
                  forKey: Key.fonts.rawValue)
    }

    private static func readReview(_ store: UserDefaults) -> ReviewPrompt {
        guard let data = store.data(forKey: Key.review.rawValue) else { return ReviewPrompt() }
        return (try? JSONDecoder().decode(ReviewPrompt.self, from: data)) ?? ReviewPrompt()
    }

    private static func readProStatus(_ store: UserDefaults) -> ProStatus? {
        guard let data = store.data(forKey: Key.proStatus.rawValue) else { return nil }
        return try? JSONDecoder().decode(ProStatus.self, from: data)
    }

    private func write(_ key: Key, _ value: String?) {
        if let value {
            store.set(value, forKey: key.rawValue)
        } else {
            store.removeObject(forKey: key.rawValue)
        }
    }

    private static func read(_ store: UserDefaults, _ key: Key) -> String? {
        store.string(forKey: key.rawValue)
    }

    /// Общий разбор словаря «область → значение»: у наборов, фонов, шрифтов и
    /// выравниваний он один и тот же.
    private static func readMap<T>(_ store: UserDefaults, _ key: Key,
                                   _ make: (String) -> T?) -> [AppearanceArea: T] {
        let raw = store.dictionary(forKey: key.rawValue) as? [String: String] ?? [:]
        var out: [AppearanceArea: T] = [:]
        for (area, value) in raw {
            if let a = AppearanceArea(rawValue: area), let v = make(value) { out[a] = v }
        }
        return out
    }

    private static func readScenes(_ store: UserDefaults) -> [AppearanceArea: VerseScene] {
        let raw = store.dictionary(forKey: Key.scenes.rawValue) as? [String: String] ?? [:]
        var out: [AppearanceArea: VerseScene] = [:]
        for (area, scene) in raw {
            if let a = AppearanceArea(rawValue: area), let s = VerseScene(rawValue: scene) {
                out[a] = s
            }
        }
        return out
    }

    private static func readStyles(_ store: UserDefaults) -> [AppearanceArea: VerseStyle] {
        let raw = store.dictionary(forKey: Key.styles.rawValue) as? [String: String] ?? [:]
        var out: [AppearanceArea: VerseStyle] = [:]
        for (area, style) in raw {
            if let a = AppearanceArea(rawValue: area), let s = VerseStyle(rawValue: style) {
                out[a] = s
            }
        }
        return out
    }
}

/// Варианты иконки приложения. Альтернативные — за подпиской, кроме «Ночи».
///
/// Все восемь — готовые изображения без людей и божеств: светильник, лотос, мандала, храм,
/// рассвет. Списком заведует `tools/art/build_assets.py`: имена наборов в каталоге
/// обязаны совпадать с `alternateName`, иначе `setAlternateIconName` их не найдёт.
public enum AppIcon: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case `default`
    case night
    case lotus
    case om
    case dawn
    case temple
    case mandala
    case light

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .default: .iconDefault
        case .night: .iconNight
        case .lotus: .iconLotus
        case .om: .iconOm
        case .dawn: .iconDawn
        case .temple: .iconTemple
        case .mandala: .iconMandala
        case .light: .iconLight
        }
    }

    /// `nil` для основной — так этого требует `setAlternateIconName`.
    public var alternateName: String? {
        self == .default ? nil : rawValue
    }

    /// Имя картинки в ресурсах `DeepamUI` для плитки в выборе.
    ///
    /// Картинка, а не рецепт: наборы иконок лежат в бандле приложения, а экран
    /// выбора собирается в пакете и до них не дотягивается, поэтому для плиток
    /// те же изображения лежат и в ресурсах пакета.
    public var previewAsset: String? { "icon-\(rawValue)" }

    /// Градиент подложки плитки, пока картинка не прорисовалась.
    public var swatch: (top: UInt32, bottom: UInt32, lamp: UInt32?) {
        (0x311A42, 0x180D1F, nil)
    }

    /// Бесплатны основная и «Ночь»: в онбординге человек выбирает иконку, и выбор,
    /// который срабатывает сразу, а не «после Pro», и есть то «ага», ради
    /// которого шаг затевался. Одной основной для этого мало.
    public var isPremium: Bool { self != .default && self != .night }
}
