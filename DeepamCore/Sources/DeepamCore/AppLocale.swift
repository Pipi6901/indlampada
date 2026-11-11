import Foundation

/// Языки релиза. Одновременно и код языка, и имя файла корпуса.
///
/// В первой версии язык один — английский: перевод Бхагавад-гиты Анни Безант (1922) с
/// санскритским оригиналом в деванагари. Остальные языки добавляются вместе с переводом,
/// который можно свободно распространять (см. `docs/TRANSLATIONS.md`): для русского и хинди
/// такого текста с привязкой к стихам пока нет.
///
/// Как добавить язык: `case` здесь, колонка строк в `tools/i18n`, перевод в `tools/corpus`
/// (`EDITIONS`), названия в `DeepamUI/Editions.swift`, ветка в `L10n.count`.
public enum AppLocale: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }

    case en

    /// Язык по настройкам устройства.
    ///
    /// Берётся `preferredLanguages`, а не `Locale.current`: человек может
    /// держать регион США и первым языком русский, и показывать ему при этом
    /// английский было бы неверно. Список перебирается по порядку, поэтому
    /// выигрывает первый язык, который мы поддерживаем.
    public static func detect(
        preferred: [String] = Locale.preferredLanguages
    ) -> AppLocale {
        for tag in preferred {
            let code = Locale(identifier: tag).language.languageCode?.identifier
            if let code, let match = AppLocale(rawValue: code) {
                return match
            }
        }
        return .en
    }

    /// Пишется справа налево. Интерфейс на таком языке зеркалится целиком. Сейчас таких
    /// языков нет; свойство осталось, потому что от него зависит раскладка экранов.
    public var isRightToLeft: Bool { false }

    /// Локаль для форматов дат и чисел.
    public var formattingLocale: Locale {
        switch self {
        case .en: Locale(identifier: "en")
        }
    }
}
