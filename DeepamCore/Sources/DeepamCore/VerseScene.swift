import Foundation

/// Фон-изображение вместо цветной заливки.
///
/// Выбирается там же, где наборы цвета, и тем же жестом: это второй ряд плиток
/// на экране «Вид». Одно исключает другое — выбрал картинку, цветной набор
/// перестаёт действовать, и наоборот.
///
/// Все сюжеты без людей, божеств и животных: Гималаи на рассвете, Ганга с плывущими огоньками,
/// храмовая башня, светильник, лотос, ранголи и мандала.
///
/// У каждого фона своя палитра. Она не декоративная: из неё выводятся плашки,
/// линии, приглушённый текст и заливка кнопок — всё то же, что у цветных
/// наборов. Значения посчитаны по самим изображениям (`tools/art/build_assets.py`),
/// а не подобраны на глаз.
///
/// ФАЙЛ СГЕНЕРИРОВАН `tools/art/build_assets.py` — не править руками.
public enum VerseScene: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case himalaya
    case ganga
    case temple
    case diya
    case lotus
    case rangoli
    case mandala

    public var id: String { rawValue }

    /// Имя набора в каталоге. Формат подставляется по месту: `-tall` для экрана
    /// и обоев, `-wide` для среднего виджета и StandBy, `-square` для остальных.
    public var asset: String { "bg-\(rawValue)" }

    /// Светлый ли текст поверх картинки.
    ///
    /// Определяется самим изображением: тёмная картинка — светлый текст.
    public var prefersLightText: Bool {
        switch self {
        case .himalaya, .ganga, .temple, .diya, .lotus, .mandala: true
        case .rangoli: false
        }
    }

    /// Плотность подложки под текстом.
    ///
    /// Ноль означает, что картинка держит текст сама. Значения посчитаны от
    /// яркости в той полосе, где реально лежит стих: подложка доводит контраст до
    /// 4,5:1 — порога, ниже которого текст на светлом участке перестаёт
    /// читаться. Подложка не сплошная, а сгущается только в этой полосе, иначе
    /// картинка гаснет целиком и смысл её теряется.
    public var scrim: Double {
        switch self {
        case .himalaya: 0.24
        case .ganga: 0.0
        case .temple: 0.38
        case .diya: 0.0
        case .lotus: 0.0
        case .rangoli: 0.0
        case .mandala: 0.0
        }
    }

    /// Полоса, в которой подложка держится на полную силу, в долях высоты
    /// экрана. Совпадает с местом ссылки, стиха и плашки контекста.
    public static let textBand: ClosedRange<Double> = 0.27...0.67

    public var titleKey: L10n.Key {
        switch self {
        case .himalaya: .sceneHimalaya
        case .ganga: .sceneGanga
        case .temple: .sceneTemple
        case .diya: .sceneDiya
        case .lotus: .sceneLotus
        case .rangoli: .sceneRangoli
        case .mandala: .sceneMandala
        }
    }

    /// Бесплатны только «Гималаи» — самый спокойный фон. Остальные за подпиской:
    /// это и есть тот платный набор, ради которого фоны затевались.
    public var isPremium: Bool { self != .himalaya }

    /// Те же четыре цвета, что у цветного набора. `background` здесь не рисуется
    /// (сверху лежит картинка), но задаёт светлоту для плашек и кнопок.
    public var palette: (background: UInt32, second: UInt32, text: UInt32, accent: UInt32) {
        switch self {
        case .himalaya: (0x653A64, 0x4E2E55, 0xEEECE6, 0xF6B26A)
        case .ganga: (0x311D29, 0x321F29, 0xEEECE6, 0xF4A340)
        case .temple: (0x83436C, 0x6E4555, 0xEEECE6, 0xFFB257)
        case .diya: (0x3C1F32, 0x462630, 0xEEECE6, 0xFFC95C)
        case .lotus: (0x331B46, 0x47284F, 0xEEECE6, 0xF48FB1)
        case .rangoli: (0xFCECD8, 0xF9E7D1, 0x201C1A, 0x9C2F63)
        case .mandala: (0x512742, 0x411F3B, 0xEEECE6, 0xF2C45E)
        }
    }
}
