import DeepamCore
import SwiftUI

/// Вкладки приложения. Их ровно три, и добавлять четвёртую не планируется:
/// «Сегодня» — то, ради чего открывают, «Места» — то, ради чего ставят,
/// «Вид» — то, что настраивают один раз.
public enum Tab: String, Sendable, Hashable, CaseIterable, Identifiable {
    case today
    case places
    case look

    public var id: String { rawValue }

    /// Вкладка по имени шага тура. Тур живёт в `DeepamCore` и про перечисление
    /// вкладок не знает — знать ему и незачем.
    init(coachTab: String) {
        self = Tab(rawValue: coachTab) ?? .today
    }

    var titleKey: L10n.Key {
        switch self {
        case .today: .tabToday
        case .places: .placesTitle
        case .look: .lookTitle
        }
    }

    /// Значки вкладок — системные символы: пламя (светильник) для стиха дня,
    /// сетка виджетов для «Мест», палитра для «Вида». Объёмные картинки
    /// прежнего приложения (огонь, телефон) к новому образу не подходят, а
    /// символы сами подстраиваются под размер шрифта и тёмную тему.
    var symbol: String {
        switch self {
        case .today: "flame.fill"
        case .places: "square.grid.2x2.fill"
        case .look: "paintpalette.fill"
        }
    }
}
