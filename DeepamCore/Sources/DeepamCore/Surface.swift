import Foundation

/// Поверхность — место, где человек видит стих, не открывая приложение.
///
/// Продукт живёт снаружи приложения, поэтому поверхности здесь не «настройки»,
/// а сама суть: их число на человека — главная метрика.
public enum Surface: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case lockScreen
    case homeScreen
    case controlCenter
    case standBy
    case appleWatch
    case wallpaper
    case pauseBeforeFeed

    public var id: String { rawValue }

    /// Раздел на экране «Места». В макете их два, и делятся они не по типу
    /// техники, а по роли: одни поверхности человек видит, когда смотрит на
    /// экран, другая срабатывает в момент действия.
    public enum Group: String, Sendable, Hashable, CaseIterable {
        case screens
        case moment

        public var titleKey: L10n.Key {
            switch self {
            case .screens: .groupScreens
            case .moment: .groupMoment
            }
        }
    }

    public var group: Group {
        self == .pauseBeforeFeed ? .moment : .screens
    }

    /// Поверхности, которые в этой версии действительно есть.
    ///
    /// Apple Watch уехали в V2.0, и плитку убрали совсем. Раньше она висела
    /// неактивной — «есть, но поставить нельзя»; на деле это просто дразнит и
    /// портит счётчик: «светятся 3 из 7» при семи достижимых шести.
    public static var shipped: [Surface] { allCases.filter(\.isAvailable) }

    public static func all(in group: Group) -> [Surface] {
        shipped.filter { $0.group == group }
    }

    /// У StandBy и Apple Watch названия одинаковы во всех языках — это имена
    /// продуктов Apple, и переводить их не надо.
    public var titleKey: L10n.Key? {
        switch self {
        case .lockScreen: .surfaceLock
        case .homeScreen: .surfaceHome
        case .controlCenter: .surfaceControl
        case .standBy, .appleWatch: nil
        case .wallpaper: .surfaceWallpaper
        case .pauseBeforeFeed: .surfacePause
        }
    }

    /// Название, когда переводить нечего: имя продукта Apple как есть.
    public var untranslatedTitle: String {
        switch self {
        case .standBy: "StandBy"
        case .appleWatch: "Apple Watch"
        default: ""
        }
    }

    /// Подпись под названием. Есть только у «Паузы»: она одна занимает целую
    /// строку и может себе позволить вторую строчку.
    /// Пока `nil` у всех. Здесь стояло «4 приложения», но число было выдумано:
    /// выбора приложений в Deepam нет, а сколько автоматизаций человек завёл в
    /// «Командах», приложению узнать неоткуда. Настоящий счётчик появится
    /// вместе с выбором приложений через Screen Time — там он берётся из
    /// `FamilyActivitySelection.applicationTokens.count`.
    public var subtitleKey: L10n.Key? { nil }

    /// Что доступно без подписки.
    ///
    /// «Пауза перед лентой» бесплатна намеренно, хотя и сложнее остальных в
    /// реализации: это отличие продукта от всех прочих виджетов со стихами, и
    /// прятать его за оплатой значит прятать сам повод поставить приложение.
    public var isPremium: Bool {
        switch self {
        case .lockScreen, .homeScreen, .controlCenter, .pauseBeforeFeed: false
        case .standBy, .appleWatch, .wallpaper: true
        }
    }

    /// Приложение для часов приедет во втором релизе. Сам случай в перечислении
    /// оставлен: на него ссылаются строки, инструкция и метаданные, а выкинуть
    /// его целиком значило бы вычистить всё это и вернуть обратно через релиз.
    public var isAvailable: Bool { self != .appleWatch }

    /// Заголовок шторки «Как поставить».
    public var instructionTitleKey: L10n.Key {
        switch self {
        case .lockScreen: .howLock
        case .homeScreen: .howHome
        case .controlCenter: .howControl
        case .standBy: .howStandBy
        case .appleWatch: .howWatch
        case .wallpaper: .howWallpaper
        case .pauseBeforeFeed: .surfacePause
        }
    }

    /// Шаг инструкции: что нажать и что при этом произойдёт.
    ///
    /// Подсказка под шагом важнее, чем кажется: она подтверждает, что человек
    /// попал куда надо, и он не бросает на середине, увидев незнакомый экран.
    public struct Step: Sendable, Hashable, Identifiable {
        public let titleKey: L10n.Key
        public let hintKey: L10n.Key
        public var id: String { titleKey.rawValue }

        init(_ titleKey: L10n.Key, _ hintKey: L10n.Key) {
            self.titleKey = titleKey
            self.hintKey = hintKey
        }
    }

    /// Названия системных пунктов повторяются дословно: человек сверяет их
    /// глазами с экраном, и вольный пересказ только мешает.
    /// Названия системных пунктов взяты так, как они называются в самой iOS на
    /// каждом языке, а не переведены дословно: человек сверяет их глазами с
    /// экраном, и «Ajouter un contrôle» вместо « Ajouter une commande » отправит
    /// его искать пункт, которого там нет.
    public var steps: [Step] {
        switch self {
        case .lockScreen:
            [.init(.stepLock1, .stepLock1Hint),
             .init(.stepLock2, .stepLock2Hint),
             .init(.stepLock3, .stepLock3Hint)]
        case .homeScreen:
            [.init(.stepHome1, .stepHome1Hint),
             .init(.stepHome2, .stepHome2Hint),
             .init(.stepHome3, .stepHome3Hint)]
        case .controlCenter:
            [.init(.stepControl1, .stepControl1Hint),
             .init(.stepControl2, .stepControl2Hint),
             .init(.stepControl3, .stepControl3Hint)]
        case .standBy:
            [.init(.stepStandBy1, .stepStandBy1Hint),
             .init(.stepStandBy2, .stepStandBy2Hint),
             .init(.stepStandBy3, .stepStandBy3Hint)]
        case .appleWatch:
            [.init(.stepWatch1, .stepWatch1Hint),
             .init(.stepWatch2, .stepWatch2Hint),
             .init(.stepWatch3, .stepWatch3Hint)]
        case .wallpaper:
            [.init(.stepWallpaper1, .stepWallpaper1Hint),
             .init(.stepWallpaper2, .stepWallpaper2Hint),
             .init(.stepWallpaper3, .stepWallpaper3Hint)]
        case .pauseBeforeFeed:
            [.init(.stepPause1, .stepPause1Hint),
             .init(.stepPause2, .stepPause2Hint),
             .init(.stepPause3, .stepPause3Hint)]
        }
    }

    /// Приписка внизу шторки. У виджетов приложение узнаёт об установке само —
    /// расширение приходит за данными, и это видно. У обоев и паузы узнать
    /// неоткуда, поэтому там человек отмечает сам.
    public var installNoteKey: L10n.Key {
        switch self {
        case .lockScreen, .homeScreen, .controlCenter, .standBy: .noteAuto
        case .appleWatch: .noteSecondRelease
        case .wallpaper, .pauseBeforeFeed: .noteManual
        }
    }

    /// Обои и пауза ставятся через системные приложения, поэтому в шторке
    /// появляется кнопка наружу.
    public var opensSystemApp: Bool { systemAppURL != nil }

    /// Куда именно ведёт эта кнопка.
    ///
    /// Раньше обе поверхности открывали Настройки, хотя пауза настраивается в
    /// «Командах»: человека отправляли не туда, где ему надо оказаться.
    /// Пауза ведёт сразу на вкладку «Автоматизация», а не на главный экран
    /// «Команд»: первый же шаг инструкции требует именно её, и высаживать
    /// человека там, откуда надо ещё куда-то перейти, — половина работы.
    ///
    /// Адрес вкладки Apple не документирует; он собран по образцу
    /// `shortcuts://gallery`, который вкладку открывает. Если «Команды» его не
    /// поймут, они откроются на главном экране — то есть ровно так, как было.
    public var systemAppURL: URL? {
        switch self {
        case .wallpaper: URL(string: "App-Prefs:")
        case .pauseBeforeFeed: URL(string: "shortcuts://automation")
        default: nil
        }
    }

    /// Ссылка на готовую команду «Пауза Deepam» в iCloud.
    ///
    /// Заполняется руками и один раз. Ссылку вида `icloud.com/shortcuts/<id>`
    /// Apple выдаёт только в момент, когда командой делятся с устройства, —
    /// сгенерировать её из проекта нельзя. Сам файл команды лежит в
    /// `App/Пауза Deepam.shortcut`, пересобирается `make_shortcut.py`.
    ///
    /// Пусто — кнопки «Поставить команду» просто нет, и человек собирает
    /// команду по шагам, как раньше. Это рабочее состояние, а не поломка.
    /// СЕЙЧАС ПУСТО, и это решение, а не забывчивость. Готовая команда собрана
    /// под прежнюю схему из двух действий — с системным «Открыть приложение»,
    /// от которого мы отказались: именно она давала «Сбой автоматизации».
    /// Под новую схему готовая команда не помогает: соцсеть указывается
    /// параметром действия, то есть команда всё равно своя на каждое
    /// приложение, и добавить действие напрямую и проще, и короче.
    public static let readyShortcut: String? = nil

    /// Установка готовой команды одним тапом.
    ///
    /// Убирает два шага из трёх. Третий — саму автоматизацию «когда открыто
    /// приложение» — не убрать ничем: программно её создать нельзя.
    public var shortcutURL: URL? {
        guard self == .pauseBeforeFeed, let link = Surface.readyShortcut else { return nil }
        var components = URLComponents(string: "shortcuts://import-shortcut")
        components?.queryItems = [URLQueryItem(name: "url", value: link)]
        return components?.url
    }

    /// Текст главной кнопки на экране «Сегодня». Глагол разный: виджет
    /// «ставят», на рабочий стол «добавляют», паузу «включают».
    public var callToActionKey: L10n.Key {
        switch self {
        case .lockScreen: .ctaLock
        case .homeScreen: .ctaHome
        case .controlCenter: .ctaControl
        case .standBy: .ctaStandBy
        case .appleWatch: .ctaWatch
        case .wallpaper: .ctaWallpaper
        case .pauseBeforeFeed: .ctaPause
        }
    }
}
