import Foundation

/// Что открыть по тапу на уведомление.
///
/// Рассылки из консоли Firebase (Messaging → кампания → Additional options →
/// Custom data) управляют приложением ключами в данных уведомления — так
/// акцию к Пасхе или неделю перед Чёрной пятницей можно запустить без новой
/// версии:
///
/// | Ключ | Значение | Что откроется |
/// |---|---|---|
/// | `surface` | lockScreen, homeScreen, standBy, controlCenter, pauseBeforeFeed, wallpaper | инструкция поверхности |
/// | `paywall` | 1 | платный экран с текущим предложением RevenueCat |
/// | `offering` | идентификатор предложения RevenueCat, например black_friday | платный экран с этим предложением |
/// | `tab` | today, places, look | вкладка |
///
/// Ключи можно сочетать: `tab` + `paywall` откроет вкладку и поверх неё
/// платный экран. Незнакомое значение молча пропускается — опечатка в
/// кампании не должна ронять приложение или вести в пустоту.
public struct PushAction: Sendable, Equatable {
    public var surface: Surface?
    /// Открыть платный экран.
    public var paywall = false
    /// Предложение RevenueCat для платного экрана. `nil` — текущее.
    public var offering: String?
    /// Вкладка — строкой: перечисление вкладок живёт в интерфейсе.
    public var tab: String?
    /// Имя кампании Firebase — для аналитики. `nil` у своих напоминаний.
    public var campaign: String?

    public init() {}

    public init(userInfo: [AnyHashable: Any]) {
        surface = Self.text(userInfo[Reminder.surfaceKey]).flatMap(Surface.init(rawValue:))
        offering = Self.text(userInfo["offering"])
        paywall = offering != nil || Self.text(userInfo["paywall"]).map(Self.isYes) == true
        tab = Self.text(userInfo["tab"])
        // Firebase кладёт сюда название кампании из консоли, а метку
        // аналитики — если её задали. Есть любое из полей — значит, это
        // рассылка, а не своё напоминание.
        if userInfo["google.c.a.c_id"] != nil || userInfo["gcm.message_id"] != nil {
            campaign = Self.text(userInfo["google.c.a.c_l"]) ?? Self.text(userInfo["gcm.n.analytics_label"]) ?? "campaign"
        }
    }

    /// Пустые строки и пробелы — то же, что отсутствие ключа: консоль
    /// оставляет поле пустым, если значение стёрли.
    private static func text(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespaces), !string.isEmpty else {
            return nil
        }
        return string
    }

    private static func isYes(_ value: String) -> Bool {
        !["0", "false", "no"].contains(value.lowercased())
    }
}
