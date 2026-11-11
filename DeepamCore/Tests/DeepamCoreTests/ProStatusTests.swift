import Foundation
import Testing
@testable import DeepamCore

@Suite("Подписка там, куда RevenueCat не дотягивается")
struct ProStatusTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    private func makeStore() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "pro.tests." + UUID().uuidString))
    }

    // MARK: - Снимок

    /// Отменённый триал — ровно тот случай, ради которого всё затевалось:
    /// неделю он действует, после конца — нет.
    @Test
    func `отменённый триал действует до конца недели`() {
        let status = ProStatus(isActive: true, expiresAt: now.addingTimeInterval(3 * day), willRenew: false)
        #expect(status.grants(at: now))
        #expect(!status.grants(at: now.addingTimeInterval(4 * day)))
    }

    /// Продлевающаяся подписка обновилась, пока приложение не открывали, и
    /// снимок знает только старую дату. Замок в StandBy за свои же деньги —
    /// худшее, что тут может случиться.
    @Test
    func `продлевающаяся подписка не гаснет по старой дате`() {
        let status = ProStatus(isActive: true, expiresAt: now, willRenew: true)
        #expect(status.grants(at: now.addingTimeInterval(30 * day)))
    }

    @Test
    func `без права ничего не действует`() {
        #expect(!ProStatus.noSubscription.grants(at: now))
        let expired = ProStatus(isActive: false, expiresAt: now.addingTimeInterval(day), willRenew: true)
        #expect(!expired.grants(at: now))
    }

    /// Снимок от прежней версии поля `isTrial` не знает — он обязан читаться,
    /// иначе виджет до первого ответа RevenueCat считал бы подписку неизвестной.
    @Test
    func `старый снимок без признака триала читается`() throws {
        let json = #"{"isActive":true,"willRenew":false,"expiresAt":800000000}"#
        let status = try JSONDecoder().decode(ProStatus.self, from: Data(json.utf8))
        #expect(status.isActive)
        #expect(!status.isTrial)
    }

    /// Лист «почему отменил?» — только для триала с выключенным продлением.
    @Test
    func `отменённый триал узнаётся`() {
        #expect(ProStatus(isActive: true, expiresAt: now, willRenew: false, isTrial: true).isCancelledTrial)
        #expect(!ProStatus(isActive: true, expiresAt: now, willRenew: true, isTrial: true).isCancelledTrial)
        #expect(!ProStatus(isActive: true, expiresAt: now, willRenew: false, isTrial: false).isCancelledTrial)
        #expect(!ProStatus(isActive: false, expiresAt: now, willRenew: false, isTrial: true).isCancelledTrial)
    }

    // MARK: - Виджет

    /// Неизвестный статус — виджет обновился, а приложение с тех пор не
    /// открывали. Платное к этому моменту выбирали только по подписке, и
    /// отнимать его по незнанию нельзя.
    @Test
    func `неизвестный статус не отнимает платное`() throws {
        let settings = AppSettings(store: try makeStore())
        settings.setScene(.temple, for: .widgets)

        #expect(settings.proStatus == nil)
        #expect(settings.allowsPro(at: now))
        #expect(settings.effectiveScene(for: .widgets, at: now) == .temple)
    }

    /// Приложение после конца подписки не открывали, а виджет всё равно
    /// обязан отпустить платное в срок.
    @Test
    func `виджет отпускает платное в момент конца подписки`() throws {
        let settings = AppSettings(store: try makeStore())
        settings.setStyle(.dawn, for: .widgets)
        settings.setScene(.temple, for: .widgets)
        settings.setFont(.lora, for: .widgets)
        settings.updateProStatus(ProStatus(isActive: true, expiresAt: now, willRenew: false))

        let before = now.addingTimeInterval(-60)
        #expect(settings.effectiveScene(for: .widgets, at: before) == .temple)
        #expect(settings.effectiveStyle(for: .widgets, at: before) == .dawn)
        #expect(settings.effectiveFont(for: .widgets, at: before) == .lora)

        let after = now.addingTimeInterval(60)
        #expect(settings.effectiveScene(for: .widgets, at: after) == nil)
        #expect(settings.effectiveStyle(for: .widgets, at: after) == .parchment)
        #expect(settings.effectiveFont(for: .widgets, at: after) == .system)
    }

    /// Бесплатное без подписки никуда не девается.
    @Test
    func `бесплатное оформление виджету не мешает`() throws {
        let settings = AppSettings(store: try makeStore())
        settings.setStyle(.amber, for: .widgets)
        settings.setScene(.himalaya, for: .widgets)
        settings.updateProStatus(.noSubscription)

        #expect(settings.effectiveStyle(for: .widgets, at: now) == .amber)
        #expect(settings.effectiveScene(for: .widgets, at: now) == .himalaya)
        #expect(settings.effectiveFont(for: .widgets, at: now) == .system)
    }

    // MARK: - Откат в приложении

    /// Снимается только платное и на ближайшее бесплатное: светлый набор
    /// уходит в светлый, бесплатный фон остаётся.
    @Test
    func `откат снимает только платное`() throws {
        let settings = AppSettings(store: try makeStore())
        settings.setStyle(.opal, for: .app)
        settings.setScene(.himalaya, for: .app)
        settings.setStyle(.parchment, for: .widgets)
        settings.setFont(.cormorant, for: .lockScreen)
        settings.appIcon = AppIcon.temple.rawValue

        #expect(settings.dropPremiumAppearance())

        #expect(settings.style(for: .app) == .saffron)
        #expect(settings.scene(for: .app) == .himalaya)
        #expect(settings.style(for: .widgets) == .parchment)
        #expect(settings.font(for: .lockScreen) == .system)
        #expect(settings.appIcon == AppIcon.default.rawValue)
    }

    /// По возвращаемому значению решается, показывать ли лист «подписка
    /// закончилась». Тому, кто платным не пользовался, сообщать нечего.
    ///
    /// Бесплатная картинка берётся из кода, а не названием. Здесь стояли
    /// другие картинки в расчёте, что они бесплатны, — а бесплатны только «Гималаи»,
    /// и тест падал на верном поведении отката.
    @Test
    func `без платного откат ничего не меняет`() throws {
        let free = try #require(VerseScene.allCases.first { !$0.isPremium })
        let settings = AppSettings(store: try makeStore())
        settings.setStyle(.night, for: .app)
        settings.setScene(free, for: .widgets)

        let changed = settings.dropPremiumAppearance()
        #expect(!changed)
        #expect(settings.scene(for: .widgets) == free)
    }

    /// Откат и снимок пишутся в общую группу — значит, их увидит и следующий
    /// запуск, и расширение виджета со своим экземпляром настроек.
    @Test
    func `откат и снимок переживают перезапуск`() throws {
        let store = try makeStore()
        let first = AppSettings(store: store)
        first.setScene(.diya, for: .widgets)
        first.setFont(.vollkorn, for: .app)
        let status = ProStatus(isActive: false, expiresAt: now, willRenew: false)
        first.updateProStatus(status)
        first.dropPremiumAppearance()

        let second = AppSettings(store: store)
        #expect(second.scene(for: .widgets) == nil)
        #expect(second.font(for: .app) == .system)
        #expect(second.proStatus == status)
    }

    /// Каждый платный набор обязан уходить в бесплатный — иначе откат
    /// оставил бы платное на месте.
    @Test
    func `замена платного набора всегда бесплатна`() {
        for style in VerseStyle.allCases {
            #expect(!style.freeEquivalent.isPremium, "\(style.rawValue)")
        }
    }
}
