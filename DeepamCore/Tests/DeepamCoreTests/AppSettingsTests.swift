import Foundation
import Testing
@testable import DeepamCore

@Suite("Настройки и поверхности")
struct AppSettingsTests {

    /// Своё хранилище на каждый тест: они гоняются параллельно и не должны
    /// топтаться ни друг по другу, ни по настройкам разработчика.
    private func makeSettings() throws -> AppSettings {
        let name = "test.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        return AppSettings(store: store)
    }

    @Test
    func `на чистой установке ни одной поверхности`() throws {
        let settings = try makeSettings()
        #expect(settings.enabledSurfaces.isEmpty)
        #expect(settings.hasNoSurfaces)
        #expect(!settings.hasAllSurfaces)
        #expect(!settings.hasSeenOnboarding)
    }

    /// Решение куратора: оригинал на санскрите изначально выключен, а в «Виде» его можно
    /// включить, и выбор запоминается.
    @Test
    func `санскритский оригинал по умолчанию выключен и включается в настройках`() throws {
        let name = "test.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        let settings = AppSettings(store: store)
        #expect(!settings.showsOriginal)
        settings.showsOriginal = true
        #expect(AppSettings(store: store).showsOriginal)
        settings.showsOriginal = false
        #expect(!AppSettings(store: store).showsOriginal)
    }

    /// Приглашение на экране «Сегодня» ведёт к ближайшей непоставленной, и
    /// порядок здесь — от простого к сложному, а не случайный.
    @Test
    func `следующая поверхность идёт по порядку сложности`() throws {
        let settings = try makeSettings()
        #expect(settings.nextSurface == .lockScreen)
        settings.markInstalled(.lockScreen)
        #expect(settings.nextSurface == .homeScreen)
        settings.markInstalled(.homeScreen)
        #expect(settings.nextSurface == .controlCenter)
    }

    /// «Всё поставлено» должно наступать по достижимым поверхностям. Считай мы
    /// по всем случаям — состояние не наступило бы никогда: часы поставить
    /// нельзя, они выходят во втором релизе.
    @Test
    func `когда всё поставлено, предлагать нечего`() throws {
        let settings = try makeSettings()
        for surface in Surface.shipped { settings.markInstalled(surface) }
        #expect(settings.hasAllSurfaces)
        #expect(settings.nextSurface == nil)
    }

    @Test
    func `отметку можно снять`() throws {
        let settings = try makeSettings()
        settings.markInstalled(.standBy)
        settings.markRemoved(.standBy)
        #expect(!settings.enabledSurfaces.contains(.standBy))
    }

    /// Настройки читают и расширения виджета, поэтому они обязаны переживать
    /// перезапуск — и это проверяется на настоящем хранилище, а не на моке.
    @Test
    func `настройки переживают перезапуск`() throws {
        let name = "test.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        let first = AppSettings(store: store)
        first.language = .en
        first.themes = ["страх", "усталость"]
        first.hasSeenOnboarding = true
        first.markInstalled(.wallpaper)
        first.setStyle(.amber, for: .widgets)
        first.appIcon = AppIcon.night.rawValue

        let second = AppSettings(store: store)
        #expect(second.language == .en)
        #expect(second.themes == ["страх", "усталость"])
        #expect(second.hasSeenOnboarding)
        #expect(second.enabledSurfaces == [.wallpaper])
        #expect(second.style(for: .widgets) == .amber)
        #expect(second.appIcon == AppIcon.night.rawValue)
    }

    @Test
    func `стиль задаётся для каждой области отдельно`() throws {
        let settings = try makeSettings()
        settings.setStyle(.parchment, for: .app)
        settings.setStyle(.coal, for: .widgets)
        #expect(settings.style(for: .app) == .parchment)
        #expect(settings.style(for: .widgets) == .coal)
        #expect(settings.style(for: .lockScreen) == .night)   // не трогали
    }

    /// «Пауза перед лентой» бесплатна намеренно: это отличие продукта, и за
    /// оплатой оно прячет сам повод поставить приложение.
    @Test
    func `пауза перед лентой бесплатна`() {
        let free = Surface.allCases.filter { !$0.isPremium }
        #expect(free == [.lockScreen, .homeScreen, .controlCenter, .pauseBeforeFeed])
        #expect(!Surface.pauseBeforeFeed.isPremium)
    }

    /// Витрина, на которой всё под замком, отталкивает — поэтому первый ряд
    /// из четырёх наборов доступен без подписки.
    @Test
    func `первый ряд наборов доступен без подписки`() {
        let free = VerseStyle.allCases.filter { !$0.isPremium }
        #expect(free == [.saffron, .night, .parchment, .amber])
        #expect(VerseStyle.allCases.count == 8)
    }

    /// Настройки оформления читают и расширения виджета, поэтому они тоже
    /// обязаны переживать перезапуск.
    @Test
    func `настройки оформления переживают перезапуск`() throws {
        let name = "test.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: name))
        let first = AppSettings(store: store)
        first.setFont(.manrope, for: .widgets)
        first.widgetSize = .large
        first.lockLength = .short
        first.setAlignment(.center, for: .lockScreen)

        let second = AppSettings(store: store)
        #expect(second.font(for: .widgets) == .manrope)
        #expect(second.widgetSize == .large)
        #expect(second.lockLength == .short)
        #expect(second.alignment(for: .lockScreen) == .center)
        // Настройка по-областная: соседние области трогать было нечего.
        #expect(second.font(for: .app) == .system)
        #expect(second.alignment(for: .widgets) == .leading)
    }

    /// Шаг без подсказки — половина шага: подсказка подтверждает, что человек
    /// попал куда надо, и без неё он бросает на незнакомом системном экране.
    @Test
    func `у каждой поверхности три шага с подсказками`() {
        for surface in Surface.allCases {
            #expect(surface.steps.count == 3, "\(surface.rawValue)")
            #expect(surface.steps.allSatisfy { !L10n(.en)[$0.titleKey].isEmpty && !L10n(.en)[$0.hintKey].isEmpty },
                    "\(surface.rawValue)")
            let en = L10n(.en)
            #expect(!en[surface.instructionTitleKey].isEmpty)
            #expect(!en[surface.installNoteKey].isEmpty)
            #expect(!en.name(surface).isEmpty)
            #expect(!en[surface.callToActionKey].isEmpty)
        }
    }

    /// Разделы на экране «Места» должны покрывать всё, что в этой версии есть,
    /// без остатка: иначе плитка потеряется и её просто не будет видно.
    ///
    /// Сверяемся с `shipped`, а не со всеми случаями: недостижимых поверхностей
    /// на экране быть не должно вовсе.
    @Test
    func `разделы покрывают все поверхности версии`() {
        let grouped = Surface.Group.allCases.flatMap { Surface.all(in: $0) }
        #expect(Set(grouped) == Set(Surface.shipped))
        #expect(grouped.count == Surface.shipped.count)
        #expect(Surface.all(in: .moment) == [.pauseBeforeFeed])
    }

    /// Приложение для часов выходит во втором релизе. Случай в перечислении
    /// остался — на него ссылаются строки и метаданные, — но на экране его быть
    /// не должно: неактивная плитка дразнит и портит счётчик.
    @Test
    func `часы не попадают на экран`() {
        #expect(!Surface.appleWatch.isAvailable)
        #expect(!Surface.shipped.contains(.appleWatch))
        #expect(Surface.allCases.filter { !$0.isAvailable } == [.appleWatch])
    }

    /// На экране блокировки цвет задаёт система, и интерфейс обязан это знать,
    /// иначе он покажет выбор цвета, который ни на что не влияет.
    @Test
    func `экран блокировки не применяет цвет набора`() {
        #expect(!AppearanceArea.lockScreen.appliesColor)
        #expect(AppearanceArea.app.appliesColor)
        #expect(AppearanceArea.widgets.appliesColor)
    }

    @Test
    func `подписка открывает всё`() {
        let free = StubEntitlements(isSubscribed: false)
        let paid = StubEntitlements(isSubscribed: true)
        #expect(!free.isUnlocked(Surface.standBy))
        #expect(free.isUnlocked(Surface.lockScreen))
        #expect(paid.isUnlocked(Surface.standBy))
        #expect(Surface.allCases.allSatisfy { paid.isUnlocked($0) })
        #expect(VerseStyle.allCases.allSatisfy { paid.isUnlocked($0) })
        #expect(AppIcon.allCases.allSatisfy { paid.isUnlocked($0) })
    }

    /// Основная иконка задаётся не именем, а его отсутствием — этого требует
    /// `setAlternateIconName`.
    @Test
    func `основная иконка не имеет альтернативного имени`() {
        #expect(AppIcon.default.alternateName == nil)
        #expect(AppIcon.night.alternateName == "night")
        #expect(AppIcon.lotus.alternateName == "lotus")
    }

    /// Имя набора в каталоге и `alternateName` обязаны совпадать посимвольно:
    /// `setAlternateIconName` ищет по этой строке и на расхождение отвечает
    /// ошибкой, а не подстановкой чего-нибудь похожего. Наборы собирает
    /// `tools/art/build_assets.py`, а тот же список стоит в `App/make_project.py`
    /// (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`).
    @Test
    func `у каждой альтернативной иконки есть имя набора`() {
        let expected = ["night", "lotus", "om", "dawn", "temple", "mandala", "light"]
        #expect(AppIcon.allCases.compactMap(\.alternateName) == expected)
    }

    /// Бесплатных иконок две: основная и «Ночь» — на шаге иконки в
    /// онбординге хоть одна новая должна включаться сразу, без Pro.
    @Test
    func `ночь бесплатна`() {
        let free = StubEntitlements(isSubscribed: false)
        #expect(AppIcon.allCases.filter { free.isUnlocked($0) } == [.default, .night])
    }

    /// Плитки берут изображение из ресурсов пакета по имени `icon-<название>`.
    /// Пустая строка или опечатка вместо имени дала бы пустую плитку.
    @Test
    func `у каждой иконки есть имя изображения`() {
        for icon in AppIcon.allCases {
            #expect(icon.previewAsset == "icon-\(icon.rawValue)", "\(icon.rawValue)")
        }
    }
}
