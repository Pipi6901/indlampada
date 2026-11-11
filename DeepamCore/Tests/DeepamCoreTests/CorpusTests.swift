import Foundation
import Testing
@testable import DeepamCore

@Suite("Корпус")
struct CorpusTests {

    /// Число стихов в главах Бхагавад-гиты по рукописной нумерации Безант: 701 стих, в 13-й главе 35.
    private static let versesInChapter = [47, 72, 43, 42, 29, 47, 30, 28, 34, 42, 55, 20, 35, 27, 20, 24, 28, 78]

    /// Глава, первый и последний стих карточки по её идентификатору: «2-47» или «9-30-31».
    private static func span(_ id: String) -> (chapter: Int, first: Int, last: Int)? {
        let parts = id.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts.count == 3 ? parts[2] : parts[1])
    }

    @Test(arguments: AppLocale.allCases)
    func `бандл каждого языка читается`(locale: AppLocale) throws {
        let corpus = try Corpus.load(locale)
        #expect(corpus.lang == locale.rawValue)
        #expect(corpus.cards.count == 168)
        // Санскрит и перевод Анни Безант (1922) — общественное достояние: срок защиты истёк,
        // но источник указан, чтобы текст можно было сверить.
        #expect(corpus.edition.license == "Public Domain")
        let credit = try #require(corpus.sourceCredit)
        #expect(credit.contains("Besant"))
        #expect(credit.contains("1922"))
        // Уведомление в бандле и на экране «Текст и перевод» — одни и те же слова.
        #expect(corpus.sourceNotice == Legal.sourceNotice)
    }

    /// Ни одна карточка не должна приехать пустой или обрубленной.
    @Test(arguments: AppLocale.allCases)
    func `у карточек есть текст и подпись`(locale: AppLocale) throws {
        let corpus = try Corpus.load(locale)
        for card in corpus.cards {
            #expect(card.text.count >= 40, "\(card.id) в \(locale.rawValue): \(card.text)")
            #expect(card.reference.hasPrefix("Bhagavad Gita "), "\(card.id): \(card.reference)")
        }
    }

    @Test(arguments: AppLocale.allCases)
    func `у каждой карточки есть контекст`(locale: AppLocale) throws {
        let corpus = try Corpus.load(locale)
        for card in corpus.cards {
            let context = try #require(corpus.context(for: card), "нет контекста у \(card.id)")
            #expect(!context.isEmpty)
            #expect(context.split(separator: " ").count <= 34, "\(card.id): контекст длиннее 34 слов")
        }
    }

    // MARK: - Нумерация

    @Test
    func `идентификаторы уникальны, подписи совпадают с идентификаторами`() throws {
        let cards = try Corpus.load(.en).cards
        #expect(Set(cards.map(\.id)).count == cards.count)
        for card in cards {
            let span = try #require(Self.span(card.id), "странный идентификатор \(card.id)")
            let number = span.first == span.last ? "\(span.first)" : "\(span.first)–\(span.last)"
            #expect(card.reference == "Bhagavad Gita \(span.chapter).\(number)", "\(card.id): \(card.reference)")
        }
    }

    @Test
    func `стихи существуют, и ни один не входит в корпус дважды`() throws {
        var seen = Set<String>()
        for card in try Corpus.load(.en).cards {
            let span = try #require(Self.span(card.id))
            #expect((1...18).contains(span.chapter), "\(card.id)")
            #expect(span.first >= 1 && span.first <= span.last, "\(card.id)")
            #expect(span.last <= Self.versesInChapter[span.chapter - 1], "\(card.id): в главе нет такого стиха")
            #expect(span.last - span.first < 3, "\(card.id): в карточке больше трёх стихов")
            for verse in span.first...span.last {
                #expect(seen.insert("\(span.chapter).\(verse)").inserted, "стих \(span.chapter).\(verse) повторяется")
            }
        }
    }

    // MARK: - Санскрит

    /// Оригинал есть у каждой карточки и написан деванагари; перевод деванагари не содержит.
    @Test
    func `оригинал лежит в original, перевод в text`() throws {
        for card in try Corpus.load(.en).cards {
            let original = try #require(card.original, "\(card.id) без оригинала")
            #expect(original.isOriginalScript)
            #expect(!card.text.isOriginalScript, "\(card.id): перевод набран деванагари")
        }
    }

    /// Санскрит — блок деванагари, пробел, перенос строки и знаки нулевой ширины. Всё остальное
    /// (латиница, цифры, ASCII-двоеточие вместо висарги) — следы порчи при сборке.
    @Test
    func `в санскрите только деванагари, пробел и перенос`() throws {
        for card in try Corpus.load(.en).cards {
            let original = try #require(card.original)
            for scalar in original.unicodeScalars {
                let allowed = scalar == " " || scalar == "\n"
                    || (0x0900...0x097F).contains(scalar.value)
                    || scalar.value == 0x200C || scalar.value == 0x200D
                #expect(allowed, "\(card.id): U+\(String(scalar.value, radix: 16, uppercase: true))")
            }
            #expect(!original.hasPrefix(" ") && !original.hasSuffix(" ") && !original.hasSuffix("\n"), "\(card.id)")
            #expect(!original.contains("  "), "\(card.id): двойной пробел")
            #expect(!original.contains("\n\n"), "\(card.id): пустая строка")
        }
    }

    /// Каждый стих кончается знаком «॥»: сколько стихов в карточке, столько и знаков, и ни один
    /// стих не потерян при склейке. Строк — не меньше двух на стих (полустишия).
    @Test
    func `у каждого стиха санскрит доведён до конца`() throws {
        for card in try Corpus.load(.en).cards {
            let span = try #require(Self.span(card.id))
            let verses = span.last - span.first + 1
            let original = try #require(card.original)
            #expect(original.filter { $0 == "॥" }.count == verses, "\(card.id): знаков конца стиха не \(verses)")
            #expect(original.hasSuffix("॥"), "\(card.id)")
            #expect(original.split(separator: "\n").count >= 2 * verses, "\(card.id): мало строк")
        }
    }

    @Test
    func `письмо определяется по знакам деванагари`() {
        #expect("ॐ".isOriginalScript)
        #expect("कर्मण्येवाधिकारस्ते".isOriginalScript)
        #expect(!"Thy business is with the action only".isOriginalScript)
        #expect(!"".isOriginalScript)
    }

    // MARK: - Что показывать

    @Test
    func `перевод показывается с оригиналом или без него`() throws {
        let card = try #require(Corpus.load(.en).cards.first)

        let both = card.parts(locale: .en, showsOriginal: true)
        #expect(both.original == card.original)
        #expect(both.translation == card.text)

        let translationOnly = card.parts(locale: .en, showsOriginal: false)
        #expect(translationOnly.original == nil)
        #expect(translationOnly.translation == card.text)
    }

    @Test
    func `без оригинала в карточке показывается только перевод`() {
        let card = Card(id: "x", passage: "p", theme: "t", reference: "Bhagavad Gita 1.1", text: "Text")
        let parts = card.parts(locale: .en, showsOriginal: true)
        #expect(parts.original == nil)
        #expect(parts.translation == "Text")
    }

    /// Уведомление — только перевод: санскрит в баннере мелок и рисуется системным шрифтом.
    @Test
    func `текст для уведомления — перевод`() throws {
        let card = try #require(Corpus.load(.en).cards.first)
        #expect(card.notificationBody == card.text)
    }

    // MARK: - Состав и фильтр

    @Test(arguments: AppLocale.allCases)
    func `карточка не обрывается на запятой`(locale: AppLocale) throws {
        let corpus = try Corpus.load(locale)
        let unfinished: Set<Character> = [",", ";", ":", "—", "–", "-"]
        for card in corpus.cards {
            let last = try #require(card.text.last)
            #expect(!unfinished.contains(last), "\(card.id): …\(card.text.suffix(24))")
            #expect(!card.text.contains(" ,") && !card.text.contains(" ;") && !card.text.contains(" ."),
                    "\(card.id): пробел перед знаком")
            #expect(!card.text.hasPrefix("\""), "\(card.id): одинокая кавычка в начале")
        }
    }

    @Test
    func `фильтр по темам сужает пул, не ломая его`() throws {
        let corpus = try Corpus.load(.en)
        let theme = try #require(corpus.themes.sorted().first)
        let filtered = corpus.cards(themes: [theme])
        #expect(!filtered.isEmpty)
        #expect(filtered.count < corpus.cards.count)
        #expect(filtered.allSatisfy { $0.theme == theme })
        // На суженном пуле движок обязан работать так же.
        let engine = VerseEngine(poolCount: filtered.count)
        let seen = Set((0..<filtered.count).map { engine.index(offset: $0, on: 739_500) })
        #expect(seen.count == filtered.count)
    }

    /// Пустой набор тем означает «показывать всё», а не пустой пул: человек,
    /// не выбравший ничего в онбординге, должен видеть корпус целиком.
    @Test
    func `пустой набор тем не сужает пул`() throws {
        let corpus = try Corpus.load(.en)
        #expect(corpus.cards(themes: []).count == corpus.cards.count)
    }

    /// Несколько тем складываются, а не пересекаются.
    @Test
    func `несколько тем складываются`() throws {
        let corpus = try Corpus.load(.en)
        let two = Set(corpus.themes.sorted().prefix(2))
        let filtered = corpus.cards(themes: two)
        #expect(filtered.count == two.reduce(0) { $0 + corpus.cards(themes: [$1]).count })
        #expect(filtered.allSatisfy { two.contains($0.theme) })
    }

    /// В Гите мало стихов, подходящих под каждое состояние, поэтому порог низкий: пять. Темы с пулом
    /// меньше показались бы одним и тем же стихом через несколько дней.
    @Test
    func `в каждой теме не меньше пяти стихов`() throws {
        let corpus = try Corpus.load(.en)
        #expect(corpus.themes.count == 16)
        for theme in corpus.themes {
            #expect(corpus.cards(themes: [theme]).count >= 5, "тема «\(theme)»")
        }
    }

    // MARK: - Язык

    @Test
    func `язык устройства определяется по списку предпочтений`() {
        // Язык пока один, поэтому на любые предпочтения приходит английский.
        #expect(AppLocale.detect(preferred: ["en-GB"]) == .en)
        #expect(AppLocale.detect(preferred: ["ru-BY", "en-US"]) == .en)
        #expect(AppLocale.detect(preferred: ["hi-IN"]) == .en)
        #expect(AppLocale.detect(preferred: ["ja-JP"]) == .en)
        #expect(AppLocale.detect(preferred: []) == .en)
    }

    @Test
    func `справа налево не пишется ни один язык`() {
        for locale in AppLocale.allCases {
            #expect(!locale.isRightToLeft)
        }
    }
}
