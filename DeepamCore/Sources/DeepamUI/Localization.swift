import DeepamCore
import SwiftUI

/// Язык интерфейса, проброшенный по дереву вью.
///
/// Он берётся из настроек приложения, а не из языка устройства: человек
/// выбирает перевод в «Виде», и интерфейс обязан следовать за этим выбором.
/// Иначе получается разнобой — стих по-испански, а кнопки по-русски.
private struct L10nKey: EnvironmentKey {
    static let defaultValue = L10n(.detect())
}

extension EnvironmentValues {
    var l10n: L10n {
        get { self[L10nKey.self] }
        set { self[L10nKey.self] = newValue }
    }
}

extension View {
    /// Ставит язык интерфейса и заодно системную локаль — от неё зависит
    /// формат даты и разделители в числах.
    ///
    /// Основной текст пишется справа налево, и зеркалит его одна строка
    /// здесь: направление уходит по окружению во все экраны, листы и накрытия,
    /// которые снова вызывают `localized`. Стрелки, отступы `leading` и порядок
    /// в стопках переворачиваются сами.
    func localized(_ locale: AppLocale) -> some View {
        environment(\.l10n, L10n(locale))
            .environment(\.locale, locale.formattingLocale)
            .environment(\.layoutDirection, locale.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
