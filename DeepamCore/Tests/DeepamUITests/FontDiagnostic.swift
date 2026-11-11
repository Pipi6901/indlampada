import CoreText
import Foundation
import DeepamCore
import Testing
@testable import DeepamUI

@Suite("Шрифты")
struct FontTests {

    /// Все шрифты набора, кроме системного: у него нет ни своего файла, ни
    /// вариативных осей, и проверять там нечего.
    /// `nonisolated` обязательно: аргументы `@Test` вычисляются вне актора, а
    /// пакет собирается с изоляцией на `MainActor` по умолчанию.
    nonisolated static let bundled = VerseFont.allCases.filter { $0 != .system }

    /// Шрифты вариативные, и их дефолтные инстансы называются не так, как
    /// семейство. Если обращаться по PostScript-имени, оси уже не подвинуть,
    /// а если ошибиться с именем — CoreText молча подставит системный шрифт,
    /// и это видно только глазами.
    @Test(arguments: bundled)
    func `шрифт создаётся из своего семейства`(face: VerseFont) {
        #expect(Fonts.registered)
        let font = Fonts.ctFont(face.family, size: 20, axes: [Fonts.wghtTag: 400])
        #expect(CTFontCopyFamilyName(font) as String == face.family)
    }

    /// Ось `wght` должна действительно двигать начертание.
    ///
    /// Это не теория: у невариативного шрифта значение оси принимается молча и
    /// не делает ничего — полужирные подписи остались бы обычными, и заметить
    /// это можно было бы только глазами. Из-за этого из набора убраны PT Serif
    /// и Spectral, у которых вариативных версий не существует.
    @Test(arguments: bundled)
    func `ось веса двигает начертание`(face: VerseFont) {
        func weight(_ axis: CGFloat) -> Double {
            let font = Fonts.ctFont(face.family, size: 20, axes: [Fonts.wghtTag: axis])
            let traits = CTFontCopyTraits(font) as? [CFString: Any] ?? [:]
            return traits[kCTFontWeightTrait] as? Double ?? 0
        }
        let regular = weight(400)
        let semibold = weight(600)
        #expect(abs(regular) < 0.1, "\(face.family): 400 дал вес \(regular)")
        #expect(semibold > regular + 0.15,
                "\(face.family): 600 дал \(semibold) против \(regular) — ось не работает")
    }

    /// Смысл поправки в том, чтобы разные начертания выглядели одного размера.
    /// Если она посчитана верно, видимая высота букв у всех совпадает с
    /// Literata; допуск — 2%, точнее не имеет смысла.
    @Test(arguments: VerseFont.allCases)
    func `поправка выравнивает видимый размер`(face: VerseFont) {
        func opticalHeight(_ face: VerseFont) -> CGFloat {
            let size = 100 * Fonts.opticalScale(face)
            let font = face == .system
                ? CTFontCreateUIFontForLanguage(.system, size, nil)!
                : Fonts.ctFont(face.family, size: size, axes: [Fonts.wghtTag: 400])
            return CTFontGetXHeight(font) * 0.65 + CTFontGetCapHeight(font) * 0.35
        }
        let base = opticalHeight(.literata)
        let actual = opticalHeight(face)
        #expect(abs(actual - base) / base < 0.02,
                "\(face.family): видимая высота \(actual) против \(base) у Literata")
    }

    /// Ради этого всё и затевалось: при смене шрифта абзац не должен менять
    /// высоту, иначе интерфейс скачет. Проверяем, что заданная высота строки
    /// получается одинаковой у всех начертаний.
    @Test(arguments: VerseFont.allCases)
    func `высота строки одна для всех начертаний`(face: VerseFont) {
        let size: CGFloat = 19
        // Берём самое тесное значение из макетов: если сходится оно, сходятся
        // и все остальные.
        let target = Fonts.tightestLineHeight
        let spacing = Fonts.lineSpacing(face, size: size, lineHeight: target)
        let corrected = size * Fonts.opticalScale(face)
        let font = face == .system
            ? CTFontCreateUIFontForLanguage(.system, corrected, nil)!
            : Fonts.ctFont(face.family, size: corrected, axes: [Fonts.wghtTag: 400])
        let natural = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)

        // Добавка не должна упираться в ноль: это значило бы, что собственная
        // высота строки уже больше заданной и выровнять её нечем.
        #expect(spacing > 0, "\(face.family): своя высота строки \(natural) выше заданной")
        #expect(abs(natural + spacing - size * target) < 0.01)
    }

    // MARK: - Шрифт санскрита

    /// Tiro Devanagari Sanskrit не входит в набор для выбора, а ставится на санскрит
    /// всегда. Если файл не зарегистрировался или имя не совпало, CoreText молча
    /// подставит Helvetica, и знаки деванагари превратятся в пустые квадраты —
    /// заметить это можно только глазами.
    @Test
    func `шрифт санскрита находится`() {
        #expect(Fonts.registered)
        let font = Fonts.originalCTFont(size: 24)
        #expect(CTFontCopyFamilyName(font) as String == "Tiro Devanagari Sanskrit")
    }

    /// Знак «Ом», висарга, анусвара, вирама и несколько сочетаний согласных, которые чаще всего
    /// рассыпаются в слабых шрифтах. Если глифа нет, шрифт вернёт нулевой идентификатор.
    @Test
    func `в шрифте санскрита есть нужные знаки`() {
        let font = Fonts.originalCTFont(size: 24)
        let sample = "ॐ कर्मण्येवाधिकारस्ते मा फलेषु कदाचन । ज्ञानयोगव्यवस्थितिः ॥ क्ष त्र ज्ञ द्ध श्र ं ः ऽ"
        let characters = Array(sample.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        #expect(CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count))
        for (character, glyph) in zip(characters, glyphs) {
            #expect(glyph != 0, "нет глифа U+\(String(character, radix: 16, uppercase: true))")
        }
    }

    /// Все знаки, которые есть в санскрите корпуса, должны рисоваться этим шрифтом. Знаки нулевой
    /// ширины и перенос строки глифа не требуют.
    @Test
    func `шрифт санскрита покрывает весь корпус`() throws {
        let font = Fonts.originalCTFont(size: 24)
        let corpus = try Corpus.load(.en)
        let scalars = Set(corpus.cards.compactMap(\.original).flatMap { $0.unicodeScalars.map(\.value) })
            .subtracting([0x0A, 0x200C, 0x200D])
        for value in scalars.sorted() {
            var character = UniChar(value)
            var glyph: CGGlyph = 0
            #expect(CTFontGetGlyphsForCharacters(font, &character, &glyph, 1),
                    "нет глифа U+\(String(value, radix: 16, uppercase: true))")
        }
    }

    // MARK: - Размеры

    /// Санскрит над переводом не должен быть мельче перевода: его читают
    /// первым, и в Гите он главный.
    @Test
    func `оригинал крупнее перевода`() {
        let parts = VerseParts(original: String(repeating: "क", count: 90),
                               translation: String(repeating: "a", count: 90))
        let sizes = VerseSizes(parts)
        #expect(sizes.originalSize > sizes.translation)
        #expect(sizes.gap > 0)
    }

    /// Чем длиннее стих, тем мельче кегль, но не мельче читаемого.
    @Test
    func `кегль падает с длиной, но не ниже порога`() {
        var previous = CGFloat.infinity
        for length in [10, 50, 90, 150, 250, 600] {
            let sizes = VerseSizes(VerseParts(original: String(repeating: "क", count: length),
                                              translation: String(repeating: "a", count: length)))
            #expect(sizes.originalSize <= previous)
            #expect(sizes.originalSize >= 15)
            #expect(sizes.translation >= 13)
            previous = sizes.originalSize
        }
    }

    /// Один санскритский текст (в приложении так не бывает, но экран должен это пережить) крупнее,
    /// чем тот же текст над переводом: ему не нужно делить экран.
    @Test
    func `одинокий оригинал крупнее парного`() {
        let text = String(repeating: "क", count: 60)
        let alone = VerseSizes(VerseParts(original: text, translation: nil))
        let paired = VerseSizes(VerseParts(original: text, translation: "x"))
        #expect(alone.originalSize > paired.originalSize)
        #expect(alone.gap == 0)
    }

    /// Ступенька уменьшения (`ViewThatFits` на «Сегодня») масштабирует всё.
    @Test
    func `масштаб уменьшает оба кегля`() {
        let parts = VerseParts(original: String(repeating: "क", count: 90),
                               translation: String(repeating: "a", count: 90))
        let full = VerseSizes(parts)
        let small = VerseSizes(parts, factor: 0.5)
        #expect(abs(small.originalSize - full.originalSize * 0.5) < 0.001)
        #expect(abs(small.translation - full.translation * 0.5) < 0.001)
    }
}
