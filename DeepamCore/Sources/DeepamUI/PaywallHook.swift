import DeepamCore
import SwiftUI

/// Чем показывать управление подпиской.
///
/// Экран знает, КОГДА его открыть, но не знает, ЧЕМ он нарисован: отмена,
/// возврат, смена тарифа — это десяток экранов, которые RevenueCat уже написал.
/// Линковать его сюда нельзя, ту же библиотеку линкует расширение виджета,
/// поэтому готовый экран подставляется снаружи.
///
/// Пусто — строки «Подписка» в настройках просто нет: вести человека в пустоту
/// хуже, чем не показывать строку.
struct PaywallHook: Sendable {
    var customerCenter: (@MainActor () -> AnyView)?
}

private struct PaywallHookKey: EnvironmentKey {
    static let defaultValue = PaywallHook()
}

/// Магазин для платного экрана. Пусто — цены показать нечем.
private struct PaywallStoreKey: EnvironmentKey {
    // Вычисляемое, а не хранимое: у статического поля непроверяемого на
    // Sendable типа Swift 6 требует явной изоляции, а хранить тут нечего.
    static var defaultValue: (any PaywallStore)? { nil }
}

extension EnvironmentValues {
    var paywallHook: PaywallHook {
        get { self[PaywallHookKey.self] }
        set { self[PaywallHookKey.self] = newValue }
    }

    var paywallStore: (any PaywallStore)? {
        get { self[PaywallStoreKey.self] }
        set { self[PaywallStoreKey.self] = newValue }
    }
}

extension View {
    /// Подставляет экран управления подпиской. Вызывается один раз в точке входа.
    public func purchaseScreens(customerCenter: (@MainActor () -> AnyView)?) -> some View {
        environment(\.paywallHook, PaywallHook(customerCenter: customerCenter))
    }

    /// Подставляет магазин: цены и покупку. Без него платный экран остаётся
    /// витриной — показывает набор, но продать ничего не может.
    public func paywallStore(_ store: (any PaywallStore)?) -> some View {
        environment(\.paywallStore, store)
    }
}

/// Платный экран приложения. Он один: и в онбординге, и на замках внутри.
struct PaywallSheet: View {
    let settings: AppSettings
    let entitlements: any EntitlementStore
    let source: PaywallSource
    var pick: PaywallPick? = nil
    var offering: String? = nil

    var body: some View {
        PaywallScreen(settings: settings, entitlements: entitlements, source: source,
                      pick: pick, offering: offering)
    }
}
