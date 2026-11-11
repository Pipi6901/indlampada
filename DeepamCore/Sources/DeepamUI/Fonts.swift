import CoreText
import DeepamCore
import SwiftUI

/// Шрифты приложения.
///
/// ПОЧЕМУ НЕ ТЕ, ЧТО В МАКЕТЕ. В макете стоят Newsreader и Outfit, но ни один
/// из них не содержит кириллицы — вообще ни одной буквы. Для приложения, где
/// русский идёт первым из пяти языков, это не годится: система молча подменяет
/// шрифт, и «1 в 1» с макетом на русском недостижимо в принципе. Набор подобран
/// заново — все начертания покрывают латиницу с кириллицей разом, поэтому все
/// пять языков выглядят одинаково.
///
/// Все шрифты набора вариативные, и это сознательно. У невариативного шрифта
/// ось `wght` не работает: значение принимается молча, а начертание остаётся
/// обычным — полужирные подписи просто перестали бы быть полужирными. Проверять
/// это в каждом месте дороже, чем не пускать такие шрифты в набор.
///
/// У вариативного шрифта дефолтный инстанс может называться не как семейство, и
/// тогда `Font.custom` не найдёт ничего, а `.weight(.semibold)` поверх него не
/// двигает ось совсем. Отсюда работа через CoreText: шрифт создаётся по имени
/// СЕМЕЙСТВА, а начертание задаётся значением оси.
public enum Fonts {
    public static let wghtTag = axisTag("wght")
    private static let wght = wghtTag
    private static let opsz = axisTag("opsz")

    private static func axisTag(_ code: String) -> Int {
        code.utf8.reduce(0) { $0 << 8 | Int($1) }
    }

    /// Регистрация в процессе один раз при первом обращении. Вычисление
    /// `static let` ленивое и потокобезопасное — ровно то, что нужно.
    public static let registered: Bool = {
        let bundle = Bundle.module
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
        var ok = false
        for url in Set(urls) {
            ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) || ok
        }
        return ok
    }()

    // MARK: - Готовые шрифты

    public static func font(_ face: VerseFont, size: CGFloat, weight: CGFloat) -> Font {
        let corrected = size * opticalScale(face)
        guard face != .system else {
            return .system(size: corrected, weight: Font.Weight(axis: weight))
        }
        return Font(ctFont(face.family, size: corrected,
                           axes: [wght: weight, opsz: corrected]))
    }

    /// Тот же шрифт как `CTFont` — нужен тестам, чтобы проверить, что пришло
    /// действительно нужное семейство, а не системная подмена.
    public static func ctFont(_ family: String, size: CGFloat, axes: [Int: CGFloat]) -> CTFont {
        _ = registered
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: family as CFString,
            kCTFontVariationAttribute: axes.reduce(into: [CFNumber: CGFloat]()) {
                $0[$1.key as CFNumber] = $1.value
            } as CFDictionary,
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    // MARK: - Выравнивание размера

    /// На сколько умножить кегль, чтобы начертание выглядело того же размера,
    /// что и Literata.
    ///
    /// Номинальный кегль почти ничего не говорит о видимом размере: у Cormorant
    /// строчные занимают 0,386 кегельной площадки, у Manrope — 0,540. Один и тот
    /// же «18 pt» у них отличается на треть. Без поправки смена шрифта читается
    /// как смена размера — текст прыгает, хотя менялось начертание.
    ///
    /// Поправка берётся из метрик самого шрифта, а не из таблицы подобранных
    /// чисел: добавить в набор новый шрифт тогда — это одна строка в перечислении,
    /// без подгонки на глаз.
    ///
    /// Считается по высоте строчных и прописных вместе. Только по строчным —
    /// перебор: у Cormorant строчные мелкие, а прописные почти как у Literata, и
    /// выравнивание по строчным раздуло бы заголовки.
    public static func opticalScale(_ face: VerseFont) -> CGFloat {
        if let cached = scaleCache[face] { return cached }
        let value = reference == 0 ? 1 : reference / opticalHeight(measured(face, size: 100))
        scaleCache[face] = value
        return value
    }

    /// Межстрочный интервал, дающий заданную высоту строки.
    ///
    /// `lineSpacing` в SwiftUI — это добавка сверх собственной высоты строки
    /// шрифта, а она у всех разная: от 1,20 кегля у Bitter до 1,49 у Literata.
    /// Поэтому одинаковая добавка даёт разную высоту абзаца, и при смене шрифта
    /// блок текста меняет высоту, сдвигая всё под собой. Здесь добавка считается
    /// от собственных метрик, так что итоговая высота строки одна для всех.
    public static func lineSpacing(_ face: VerseFont, size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        let corrected = size * opticalScale(face)
        let font = measured(face, size: corrected)
        let natural = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        return max(0, size * lineHeight - natural)
    }

    /// Самая тесная высота строки, встречающаяся в макетах, — заголовок на
    /// экране паузы.
    ///
    /// Ниже этого значения опускаться нельзя: добавка упрётся в ноль, шрифт
    /// сохранит собственную высоту строки, и абзац станет выше остальных —
    /// ровно тот скачок, ради которого всё это и считается. Молча, потому что
    /// `max(0, …)` не может пожаловаться. Проверяется тестом на всём наборе,
    /// так что новый шрифт с высокими метриками не проскочит незамеченным.
    public static let tightestLineHeight: CGFloat = 1.685

    // MARK: - Метрики

    private static var scaleCache: [VerseFont: CGFloat] = [:]

    private static let reference: CGFloat = opticalHeight(measured(.literata, size: 100))

    private static func opticalHeight(_ font: CTFont) -> CGFloat {
        CTFontGetXHeight(font) * 0.65 + CTFontGetCapHeight(font) * 0.35
    }

    private static func measured(_ face: VerseFont, size: CGFloat) -> CTFont {
        guard face != .system else {
            return CTFontCreateUIFontForLanguage(.system, size, nil)
                ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        }
        return ctFont(face.family, size: size, axes: [wght: 400])
    }
}

extension Font.Weight {
    /// Перевод числовой оси в системный вес — для набора «Системный», где
    /// вариативных осей нет.
    init(axis: CGFloat) {
        self = switch axis {
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        default: .bold
        }
    }
}
