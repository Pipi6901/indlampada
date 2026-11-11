import Foundation

/// Карточка — единица показа. Текст уже склеен и знак в конце нормализован на
/// сборке корпуса, поэтому здесь ничего доделывать не нужно: `text` и
/// `reference` кладутся на экран как есть.
public struct Card: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    /// Отрывок, к которому карточка принадлежит. Ключ для строки контекста.
    public let passage: String
    /// Тема состояния: «страх», «усталость» и так далее.
    public let theme: String
    /// Подпись в нумерации издания: «Bhagavad Gita 2.47».
    public let reference: String
    /// Перевод.
    public let text: String
    /// Санскритский оригинал стиха (деванагари): полустишия — отдельные строки, между ними перенос.
    public var original: String? = nil

    // Ключи в бандле короткие: файл на тысячу карточек, и длинные имена
    // добавили бы к каждому языку заметный вес ни за что.
    private enum CodingKeys: String, CodingKey {
        case id
        case passage = "p"
        case theme = "th"
        case reference = "r"
        case text = "t"
        case original = "a"
    }
}

/// Из чего состоит показ карточки.
///
/// Оригинал над переводом, если человек включил оригинал в «Виде». Решается здесь, а не
/// на каждом экране: экранов семь, и расходиться в этом им нельзя.
public struct VerseParts: Sendable, Hashable {
    /// Санскритский текст стиха (деванагари).
    public let original: String?
    /// Перевод.
    public let translation: String?

    public init(original: String?, translation: String?) {
        self.original = original
        self.translation = translation
    }

    /// Самое длинное из показываемого: по нему экраны подбирают кегль.
    public var longest: Int {
        max(original?.count ?? 0, translation?.count ?? 0)
    }
}

extension Card {
    /// Что показывать на экране: перевод, а над ним по желанию оригинал.
    public func parts(locale: AppLocale, showsOriginal: Bool) -> VerseParts {
        guard showsOriginal, let original else { return VerseParts(original: nil, translation: text) }
        return VerseParts(original: original, translation: text)
    }

    /// Текст для уведомления: только перевод. Санскрит в баннере мелок и без шрифта приложения
    /// рисуется системным; оригинал человек включает на экранах приложения и в виджете.
    public var notificationBody: String { text }

    /// Укороченный текст для экрана блокировки.
    ///
    /// Места там на три строки мелким кеглем. Длинный стих система обрезает
    /// многоточием посреди слова, и выходит бессмыслица — тем более что
    /// карточка-продолжение может начинаться с середины фразы.
    ///
    /// Режем сами и по смыслу: сначала ищем конец предложения — по нему обрыв
    /// не виден вовсе, — и только если его нет, обрываем по последнему пробелу.
    public var shortText: String { Card.shorten(text) }

    /// Отдельно от `shortText`, потому что расширению виджета карточка не
    /// достаётся — у него на руках только готовая строка из ленты.
    public static func shorten(_ text: String) -> String {
        // Для санскритского хватает того же предела: `count` считает графемы, и
        // огласовки вместе с буквой — один символ, как и на глаз.
        let limit = 78
        guard text.count > limit else { return text }
        let head = text.prefix(limit)
        if let stop = head.lastIndex(where: { ".!?;".contains($0) }),
           head.distance(from: head.startIndex, to: stop) > limit / 3 {
            return String(head[...stop])
        }
        guard let space = head.lastIndex(of: " ") else { return String(head) + "…" }
        return String(head[..<space]) + "…"
    }
}

/// Издание, из которого взяты тексты.
public struct Edition: Sendable, Hashable, Codable {
    public let id: String
    public let name: String
    public let license: String
    public let source: String
}

/// Корпус одного языка: всё, что нужно приложению, и ничего лишнего.
public struct Corpus: Sendable, Hashable, Codable {
    public let schema: Int
    public let lang: String
    public let edition: Edition
    public let cards: [Card]
    /// Строка контекста по идентификатору отрывка.
    public let contexts: [String: String]
    /// Короткая строка об источнике текста: книга, переводчик, год.
    public let sourceCredit: String?
    /// Полное уведомление об источнике и статусе текста (общественное достояние);
    /// экран «Язык и перевод» показывает его целиком.
    public let sourceNotice: String?

    /// Контекст для карточки. Отсутствие контекста — не ошибка данных, а повод
    /// не показывать блок: интерфейс должен это переживать.
    public func context(for card: Card) -> String? {
        contexts[card.passage]
    }

    /// Карточки выбранных тем. Пустой набор означает весь корпус, а не пустой
    /// пул: человек, не выбравший ничего, должен видеть всё.
    ///
    /// Порядок сохраняется, поэтому индексы отфильтрованного пула остаются
    /// стабильными между запусками.
    public func cards(themes: Set<String>) -> [Card] {
        themes.isEmpty ? cards : cards.filter { themes.contains($0.theme) }
    }

    /// Все темы, встречающиеся в корпусе.
    public var themes: Set<String> {
        Set(cards.map(\.theme))
    }
}

extension Corpus {
    /// Загружает корпус языка из ресурсов пакета.
    ///
    /// Разбор синхронный и намеренно не `async`: файл лежит в бандле, читается
    /// за миллисекунды, и расширению виджета негде дожидаться задачи.
    public static func load(_ locale: AppLocale) throws -> Corpus {
        // `Bundle.module` сгенерирован как internal, поэтому в значении
        // аргумента по умолчанию его использовать нельзя — только в теле.
        try load(locale, from: .module)
    }

    /// То же, но из указанного бандла: приложение кладёт корпус в свой ресурс,
    /// а не тянет пакетный.
    public static func load(_ locale: AppLocale, from bundle: Bundle) throws -> Corpus {
        guard let url = bundle.url(forResource: "corpus-\(locale.rawValue)",
                                   withExtension: "json") else {
            throw CorpusError.missingResource(locale)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Corpus.self, from: data)
    }
}

public enum CorpusError: Error, Sendable, Hashable {
    case missingResource(AppLocale)
}

extension String {
    /// Есть ли в строке письмо деванагари (санскрит, хинди).
    ///
    /// По этому признаку экраны, виджеты и предпросмотры выбирают шрифт оригинала:
    /// латинские и кириллические начертания знаков деванагари не содержат. Лежит в
    /// ядре, а не в интерфейсе, потому что нужна и расширению виджета.
    public var isOriginalScript: Bool {
        unicodeScalars.contains {
            (0x0900...0x097F).contains($0.value)      // деванагари
                || (0xA8E0...0xA8FF).contains($0.value) // деванагари, расширение
                || (0x1CD0...0x1CFF).contains($0.value) // ведические знаки
        }
    }
}
