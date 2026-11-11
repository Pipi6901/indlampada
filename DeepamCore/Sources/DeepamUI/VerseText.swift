import CoreText
import DeepamCore
import SwiftUI

// MARK: - Шрифт оригинала

extension Fonts {
    /// PostScript-имя Tiro Devanagari Sanskrit (SIL OFL 1.1, лежит рядом с остальными
    /// шрифтами набора). Гарнитура нарисована под санскрит: в ней есть все лигатуры
    /// и сочетания согласных деванагари и ведические знаки; системный шрифт часть
    /// сочетаний набирает раздельно.
    ///
    /// Имя взято из таблицы `name` самого файла (запись 6), а не из названия файла: они
    /// разные — «TiroDevaSanskrit-Regular» против «TiroDevanagariSanskrit-Regular.ttf».
    /// Семейство — «Tiro Devanagari Sanskrit», его проверяет тест.
    ///
    /// Шрифт невариативный, поэтому работаем по имени, а не по оси, как с
    /// остальными: оси у него нет, а вес один.
    private static let originalName = "TiroDevaSanskrit-Regular"

    /// Санскритский текст стиха.
    public static func original(size: CGFloat) -> Font {
        Font(originalCTFont(size: size))
    }

    /// То же как `CTFont` — для тестов: чтобы убедиться, что пришёл именно
    /// Tiro Devanagari, а не подмена Helvetica, которую CoreText подставляет молча.
    public static func originalCTFont(size: CGFloat) -> CTFont {
        _ = registered
        return CTFontCreateWithName(originalName as CFString, size, nil)
    }
}

// MARK: - Кегли

/// Кегли санскритского оригинала и перевода на одном экране.
///
/// Кегль берётся по длине текста, как раньше брался у перевода: пул стихов
/// неоднородный, от пяти слов до целого абзаца. Когда на экране и оригинал, и
/// перевод, места на каждого вдвое меньше, поэтому таблицы у «пары» мельче, чем
/// у одинокого текста. Длина считается в символах-графемах (`count`), и
/// огласовка вместе с буквой — один символ.
struct VerseSizes: Equatable {
    let originalSize: CGFloat
    let translation: CGFloat
    /// Расстояние между оригиналом и переводом.
    let gap: CGFloat

    /// `factor` — доля от кегля экрана «Сегодня». Экрану, где места меньше
    /// (пауза), или колонке, которая не влезла, нужно то же самое, но мельче.
    init(_ parts: VerseParts, factor: CGFloat = 1) {
        let original = parts.original?.count ?? 0
        let translation = parts.translation?.count ?? 0
        let paired = original > 0 && translation > 0
        originalSize = Self.pick(original, paired ? Self.pairedOriginal : Self.soloOriginal) * factor
        self.translation = Self.pick(translation, paired ? Self.pairedTranslation : Self.soloTranslation) * factor
        gap = paired ? 16 * factor : 0
    }

    private typealias Table = [(limit: Int, size: CGFloat)]

    private static func pick(_ count: Int, _ table: Table) -> CGFloat {
        table.first { count < $0.limit }?.size ?? table.last?.size ?? 16
    }

    // Перевод сам по себе — оригинала нет (выключен в «Виде»).
    private static let soloTranslation: Table = [
        (40, 32), (90, 27), (180, 24), (320, 20), (520, 17), (.max, 15),
    ]
    // Оригинал один, без перевода (в приложении так не бывает, но экран должен это пережить).
    private static let soloOriginal: Table = [
        (30, 34), (60, 30), (100, 27), (150, 24), (200, 21), (.max, 19),
    ]
    // Оригинал над переводом. Стих в деванагари — две строки по 30–45 знаков, кегль
    // меньше, чем был у санскритского: у деванагари высокие надстрочные и подстрочные знаки.
    private static let pairedOriginal: Table = [
        (40, 26), (70, 24), (110, 21), (160, 19), (.max, 17),
    ]
    private static let pairedTranslation: Table = [
        (40, 22), (90, 20), (180, 18), (320, 16), (520, 14.5), (.max, 13.5),
    ]
}

// MARK: - Текст стиха

/// Стих на экране: санскритский оригинал (если включён), под ним перевод.
struct VerseText: View {
    @Environment(\.theme) private var theme

    let parts: VerseParts
    /// Доля от кегля «Сегодня».
    var scale: CGFloat = 1
    /// Полная высота строки перевода в долях кегля. У оригинала своя, из шрифта.
    var lineHeight: CGFloat = 1.805
    /// Цвет задаётся снаружи, когда он не из оформления приложения: на карточке
    /// для шеринга и в предпросмотре набора.
    var color: Color?
    /// Цвет перевода. Если не задан — тот же, что у оригинала.
    var translationColor: Color?
    /// Начертание перевода, когда его задаёт сам экран, а не «Вид»: онбординг
    /// набран своим шрифтом, пока человек ещё ничего не выбирал.
    var face: VerseFont?
    /// Разрядка перевода. Отрицательная — у крупных заголовков онбординга.
    var tracking: CGFloat = 0

    var body: some View {
        let sizes = VerseSizes(parts, factor: scale)
        VStack(alignment: .leading, spacing: sizes.gap) {
            if let original = parts.original {
                Text(original)
                    .font(Fonts.original(size: sizes.originalSize))
                    .foregroundStyle(color ?? theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(sizes.originalSize * 0.22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let translation = parts.translation {
                Text(translation)
                    .font(serif(sizes.translation))
                    .spaced(tracking)
                    .foregroundStyle(translationColor ?? color ?? theme.text)
                    .lineSpacing(spacing(sizes.translation))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func serif(_ size: CGFloat) -> Font {
        face.map { Fonts.font($0, size: size, weight: 400) } ?? theme.display(size)
    }

    private func spacing(_ size: CGFloat) -> CGFloat {
        face.map { Fonts.lineSpacing($0, size: size, lineHeight: lineHeight) }
            ?? theme.spacing(size, lineHeight: lineHeight)
    }
}

// MARK: - Образец без оригинала

/// Короткий образец стиха для макетов: экран блокировки в онбординге, «Что нового».
///
/// Берёт шрифт по письму строки: текст на санскрите набирается шрифтом санскрита, а не
/// начертанием, в котором санскритских букв нет. Всё остальное — цвет, число строк,
/// рамку — задаёт место вызова.
struct PlainVerse: View {
    let text: String
    let size: CGFloat
    var lineHeight: CGFloat = 1.25
    var face: VerseFont = .literata

    var body: some View {
        if text.isOriginalScript {
            Text(text).font(Fonts.original(size: size * 1.1))
        } else {
            Text(text)
                .font(Fonts.font(face, size: size, weight: 400))
                .lineSpacing(Fonts.lineSpacing(face, size: size, lineHeight: lineHeight))
        }
    }
}

// MARK: - Разрядка

extension View {
    /// Разрядка букв — только там, где она не ломает письмо.
    ///
    /// Письмо письмо связное: добавка между буквами разрывает слово на
    /// отдельные знаки и выключает лигатуры. Поэтому в основном тексте
    /// разрядка не применяется вовсе — подписи прописными с трекингом остаются
    /// приметой латиницы и кириллицы.
    func spaced(_ amount: CGFloat) -> some View {
        modifier(LetterSpacing(amount: amount))
    }
}

private struct LetterSpacing: ViewModifier {
    @Environment(\.l10n) private var l10n
    let amount: CGFloat

    func body(content: Content) -> some View {
        content.kerning(l10n.locale.isRightToLeft ? 0 : amount)
    }
}
