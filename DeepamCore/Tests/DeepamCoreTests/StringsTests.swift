import Foundation
import Testing
@testable import DeepamCore

@Suite("Строки интерфейса")
struct StringsTests {

    /// Пропущенная строка не падает, а молча отдаёт пустоту: подписи в таблице
    /// нет — subscript вернёт «». На экране это дыра, которую видно только
    /// глазами. Проверка дешёвая, а пропустить ключ при правке легко.
    @Test(arguments: AppLocale.allCases)
    func `ни один ключ не остался без строки`(locale: AppLocale) {
        let l10n = L10n(locale)
        for key in L10n.Key.allCases {
            #expect(!l10n[key].isEmpty, "\(key.rawValue) — \(locale.rawValue)")
        }
    }

    /// Подстановки — только `%@` и `%d`: любой другой процент в строке `String(format:)` прочтёт
    /// как команду и подставит мусор из памяти.
    @Test(arguments: AppLocale.allCases)
    func `в строках нет посторонних подстановок`(locale: AppLocale) {
        let l10n = L10n(locale)
        for key in L10n.Key.allCases {
            let chars = Array(l10n[key])
            for (index, char) in chars.enumerated() where char == "%" {
                let next: Character = index + 1 < chars.count ? chars[index + 1] : " "
                #expect(next == "@" || next == "d" || next == "%", "\(key.rawValue): \(l10n[key])")
            }
        }
    }

    /// Следов прежних приложений в интерфейсе быть не должно: оно собрано из кода двух других
    /// (с Библией и с Кораном), и слово из них легко остаётся в какой-нибудь строке.
    @Test(arguments: AppLocale.allCases)
    func `в строках нет следов прежних приложений`(locale: AppLocale) {
        let l10n = L10n(locale)
        let forbidden = ["Lampada", "Misbah", "Quran", "Qur’an", "Koran", "Allah", "ayah", "ayat", "surah",
                         "Arabic", "Islam", "Muslim", "mosque", "Bible", "Christ", "Jesus", "Psalm",
                         "Gospel", "church", "Scripture"]
        for key in L10n.Key.allCases {
            let text = l10n[key]
            for word in forbidden {
                #expect(!text.localizedCaseInsensitiveContains(word),
                        "\(locale.rawValue) \(key.rawValue): «\(word)» в «\(text)»")
            }
        }
    }

    /// Образцы стихов в онбординге и на экране паузы — настоящие карточки корпуса, а не набранный
    /// руками текст: стих, которого нет в книге, показывать нельзя.
    @Test
    func `образцы стихов взяты из корпуса`() throws {
        let corpus = try Corpus.load(.en)
        let l10n = L10n(.en)
        let pairs: [(verse: L10n.Key, reference: L10n.Key)] = [
            (.demoVerse, .demoReference),
            (.pauseVerse, .pauseReference),
        ]
        for pair in pairs {
            let text = l10n[pair.verse]
            let card = try #require(corpus.cards.first { $0.text == text }, "нет в корпусе: \(text)")
            #expect(card.reference == l10n[pair.reference])
        }
    }

    /// Список состояний задаёт корпус, а названия — код. Разъехаться им легко:
    /// достаточно добавить в корпус новую тему, и в онбординге появится русский
    /// идентификатор посреди английских названий — молча, потому что запасной
    /// вариант возвращает сам идентификатор.
    @Test(arguments: AppLocale.allCases)
    func `у каждого состояния из корпуса есть название`(locale: AppLocale) throws {
        let corpus = try Corpus.load(locale)
        let inCorpus = Set(corpus.cards.map(\.theme))
        for theme in inCorpus.sorted() {
            #expect(L10n.themes[theme] != nil, "нет названия: \(theme)")
        }
        // И наоборот: название состояния, которого нет в корпусе, — мусор.
        for theme in L10n.themes.keys {
            #expect(inCorpus.contains(theme), "лишнее название: \(theme)")
        }
    }

    @Test
    func `названия состояний отличаются от идентификатора`() {
        for id in L10n.themes.keys {
            for locale in AppLocale.allCases {
                let name = L10n(locale).theme(id)
                #expect(name != id, "\(locale.rawValue): \(id)")
                // Идентификаторы русские; показанное название русских букв содержать не должно.
                #expect(name.unicodeScalars.allSatisfy { !(0x0400...0x04FF).contains($0.value) }, "\(name)")
            }
        }
        #expect(L10n(.en).theme("страх") == "Fear")
        #expect(L10n(.en).theme("любовь") == "Devotion")
        #expect(L10n(.en).theme("вина") == "Regret")
        // Неизвестное состояние показывается как есть, а не пустотой.
        #expect(L10n(.en).theme("нет такого") == "нет такого")
    }

    /// Ссылки с пейволла — не украшение: по правилу 3.1.2 они обязаны быть на
    /// экране оплаты, и первую подачу ревью отклоняет именно за отсутствие
    /// условий. Проверка ловит подмену на заглушку и на http, который iOS
    /// откроет, но ревьюер засчитает за нерабочую ссылку.
    @Test
    func `ссылки на условия и политику ведут наружу`() {
        #expect(Legal.terms.scheme == "https")
        #expect(Legal.privacy.scheme == "https")
        #expect(Legal.sourceURL.scheme == "https")
        #expect(Legal.terms.host == "www.apple.com")
        #expect(Legal.privacy.path.hasSuffix("/privacy"))
        for url in [Legal.terms, Legal.privacy, Legal.sourceURL] {
            #expect(!url.absoluteString.localizedCaseInsensitiveContains("lampada"))
            #expect(!url.absoluteString.localizedCaseInsensitiveContains("misbah"))
        }
    }

    /// «1 day», «45 days»: у английского две формы.
    @Test
    func `число со словом в нужной форме`() {
        let en = L10n(.en)
        #expect(en.count(1, .daysUnit) == "1 day")
        #expect(en.count(45, .daysUnit) == "45 days")
        #expect(en.count(1, .versesUnit) == "1 verse")
        #expect(en.count(7, .versesUnit) == "7 verses")
        #expect(en.count(0, .versesUnit) == "0 verses")
        #expect(en.count(1, .fontsUnit) == "1 typeface")
        #expect(en.count(3, .iconsUnit) == "3 icons")
    }

    /// Подстановка чисел в строку с несколькими местами.
    @Test
    func `подстановки работают`() {
        let en = L10n(.en)
        #expect(en(.themesPicked, 2, 16) == "2 of 16 selected")
        #expect(en(.placesProgress, 3, 7).contains("3 of 7"))
    }

    /// Дата в макете экрана блокировки должна быть на языке интерфейса.
    @Test
    func `дата в макете переводится`() {
        #expect(L10n(.en).mockDate.contains("September"))
    }
}
