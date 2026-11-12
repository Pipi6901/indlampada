import Foundation

/// Где применяется оформление. Переключатель на экране «Вид».
public enum AppearanceArea: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case app
    case widgets
    case lockScreen

    public var id: String { rawValue }

    /// Ключ подписи, а не готовая строка: перечисление живёт в `DeepamCore` и
    /// про выбранный язык не знает — его подставляет тот, кто рисует.
    public var titleKey: L10n.Key {
        switch self {
        case .app: .areaApp
        case .widgets: .areaWidgets
        case .lockScreen: .areaLock
        }
    }

    /// На экране блокировки цвет задаёт система: виджеты там монохромные и
    /// подстраиваются под обои. Поэтому наборы стилей туда не показываются
    /// вовсе — вместо них настраиваются шрифт, длина строки и выравнивание.
    public var appliesColor: Bool { self != .lockScreen }
}

/// Набор стилей карточки со стихом.
///
/// «Ночь» — оформление по умолчанию: именно она нарисована в макете, и первый
/// запуск должен выглядеть так же. «Шафран» — яркий вариант.
public enum VerseStyle: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case saffron
    case night
    case parchment
    case amber
    case ink
    case dawn
    case opal
    case coal

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .saffron: .styleSaffron
        case .night: .styleNight
        case .parchment: .styleParchment
        case .amber: .styleAmber
        case .ink: .styleInk
        case .dawn: .styleDawn
        case .opal: .styleOpal
        case .coal: .styleCoal
        }
    }

    /// Первый ряд из четырёх доступен без подписки, второй — за ней. Витрина,
    /// на которой всё под замком, отталкивает.
    public var isPremium: Bool {
        switch self {
        case .saffron, .night, .parchment, .amber: false
        case .ink, .dawn, .opal, .coal: true
        }
    }

    /// Бесплатный набор, который встаёт на место платного, когда подписка
    /// кончилась.
    ///
    /// Ближайший по виду, а не набор по умолчанию: светлый уходит в светлый,
    /// тёмный в тёмный. Человек, выбравший светлый «Опал», иначе открыл бы
    /// приложение и обнаружил его тёмным, будто что-то сломалось.
    public var freeEquivalent: VerseStyle {
        switch self {
        case .saffron, .night, .parchment, .amber: self
        case .ink, .coal: .night
        case .dawn: .parchment
        case .opal: .saffron
        }
    }

    /// Цвета набора в виде hex, чтобы `DeepamCore` не зависел от SwiftUI и
    /// этими же значениями мог пользоваться генератор картинки для шеринга.
    ///
    /// `second` — второй цвет фона: у наборов с градиентом он отличается от
    /// первого, у плоских совпадает.
    public var palette: (background: UInt32, second: UInt32, text: UInt32, accent: UInt32) {
        switch self {
        case .saffron: (0xEE8A32, 0xB8481A, 0xFFF4E8, 0xFFE0BC)
        case .night: (0x1C0A0E, 0x3C141C, 0xF4E8DC, 0xF0913A)
        case .parchment: (0xEDE3CE, 0xE3D6BC, 0x2B1A14, 0xA8431E)
        case .amber: (0x5A2616, 0x341309, 0xF5E6D0, 0xF39A3C)
        case .ink: (0x160709, 0x0B0405, 0xE8D8CE, 0xC98B5C)
        case .dawn: (0xFAEAE0, 0xF2CDB8, 0x3A1A18, 0xC8432A)
        case .opal: (0xF8DDD2, 0xEDB4A2, 0x3A1418, 0xA3262F)
        case .coal: (0x2C2123, 0x181011, 0xE0D0C8, 0xB58C7A)
        }
    }
}

/// Размер виджета для предпросмотра на экране «Вид».
public enum WidgetSize: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case standBy

    public var id: String { rawValue }

    /// У StandBy своё имя во всех языках — это название режима iOS.
    public var titleKey: L10n.Key? {
        switch self {
        case .small: .sizeSmall
        case .medium: .sizeMedium
        case .large: .sizeLarge
        case .standBy: nil
        }
    }

    /// Пропорции превью. Настоящие виджеты iOS примерно таких соотношений,
    /// и превью должно врать как можно меньше.
    public var aspectRatio: Double {
        switch self {
        case .small: 1
        case .medium: 2.13
        case .large: 1.05
        case .standBy: 1.9
        }
    }
}

/// Сколько стиха показывать на экране блокировки.
///
/// Место там жёстко ограничено системой, и длинный стих просто обрежется —
/// поэтому выбор честный: показать начало или уместить всё мелким кеглем.
public enum VerseLength: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case short
    case full

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .short: .lengthShort
        case .full: .lengthFull
        }
    }
}

/// Выравнивание текста на экране блокировки.
public enum VerseAlignment: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case leading
    case center

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .leading: .alignLeading
        case .center: .alignCenter
        }
    }
}

/// Шрифт приложения.
///
/// В макете стояли Newsreader и Outfit, но ни один из них не содержит
/// кириллицы, поэтому набор собран заново — все начертания покрывают латиницу
/// и кириллицу разом, иначе на русском система молча подставит своё.
public enum VerseFont: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    // Системный первым: он единственный бесплатный и стоит по умолчанию, а
    // список читают сверху. Порядок здесь — это порядок в листе выбора;
    // сохраняются начертания по `rawValue`, поэтому перестановка ничего не ломает.
    case system
    case literata
    case lora
    case bitter
    case vollkorn
    case alegreya
    case cormorant
    case manrope
    case onest

    public var id: String { rawValue }

    /// Имя семейства для CoreText. Обращаться надо именно к семейству:
    /// PostScript-имя указывает на конкретный именованный инстанс, и задавать
    /// поверх него значения осей уже поздно.
    public var family: String {
        switch self {
        case .literata: "Literata"
        case .lora: "Lora"
        case .bitter: "Bitter"
        case .vollkorn: "Vollkorn"
        case .alegreya: "Alegreya"
        case .cormorant: "Cormorant Garamond"
        case .manrope: "Manrope"
        case .onest: "Onest"
        case .system: ""
        }
    }

    public var title: String {
        switch self {
        case .literata: "Literata"
        case .lora: "Lora"
        case .bitter: "Bitter"
        case .vollkorn: "Vollkorn"
        case .alegreya: "Alegreya"
        case .cormorant: "Cormorant"
        case .manrope: "Manrope"
        case .onest: "Onest"
        // Подписывается локализованной строкой на месте показа: это
        // единственное название в наборе, которое надо переводить.
        case .system: "System"
        }
    }

    /// Бесплатен только системный. Начертание меняет вид приложения сильнее
    /// любой другой настройки, поэтому оно платное, — а системный остаётся
    /// исправной точкой отсчёта, с которой приложение и открывается впервые.
    public var isPremium: Bool { self != .system }

    /// Антиква или гротеск. Список выбора делится на две группы: разница между
    /// «с засечками» и «без» — первое, по чему человек отсеивает варианты.
    public var isSerif: Bool {
        switch self {
        case .manrope, .onest, .system: false
        default: true
        }
    }
}
