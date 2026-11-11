import AppIntents
import DeepamCore
import DeepamPurchases
import DeepamUI
import SwiftUI

/// Точка входа. Всё содержимое живёт в пакете `DeepamCore`, потому что то же
/// самое линкуют расширения виджета — дублировать код между таргетами нельзя.
@main
struct DeepamApp: App {
    /// Firebase, Amplitude, Meta и приёмники событий — см. `FirebaseEvents.swift`.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Ключ RevenueCat. Публичный по замыслу: он вшивается в приложение, а
    /// покупки всё равно проверяются на сервере по чеку от Apple, поэтому
    /// прятать его не от кого.
    ///
    /// Боевой ключ приложения App Store — префикс `appl_`. Ключ тестового
    /// магазина (`test_`) сюда класть нельзя: в сборке Release SDK нарочно
    /// роняет приложение при запуске, чтобы такой ключ не уехал в App Store.
    /// Именно это положило сборку 2 в TestFlight.
    ///
    /// ПОКА ПУСТО: у Deepam свой проект RevenueCat (свой bundle ID, свои товары), и ключ чужого
    /// приложения сюда ставить нельзя — покупки уехали бы не туда. Пустой ключ значит «RevenueCat
    /// в этой сборке нет»: платный экран остаётся витриной. Как завести приложение и где взять
    /// ключ — `docs/FIRST-BUILD.md`.
    private static let revenueCatKey = ""

    /// Включён ли RevenueCat в этой сборке.
    ///
    /// В Release с тестовым ключом SDK нарочно роняет приложение при запуске,
    /// поэтому там он не поднимается вообще: платный экран остаётся витриной —
    /// показывает набор, но продать ничего не может. Заменят ключ на `appl_` —
    /// всё включится само.
    private static let usesRevenueCat = RevenueCatEntitlements.accepts(apiKey: revenueCatKey)

    private static var customerCenter: (@MainActor () -> AnyView)? {
        guard usesRevenueCat else { return nil }
        return { AnyView(DeepamCustomerCenter()) }
    }

    @State private var entitlements = RevenueCatEntitlements()

    /// Регистрация действий для «Команд».
    ///
    /// Обращение к провайдеру здесь не ради самого вызова: больше на
    /// `DeepamShortcuts` ссылок нет, метаданные типа выбрасываются при
    /// линковке, и рантайм App Intents потом его не находит.
    init() {
        DeepamShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView(entitlements: entitlements)
                // Цены, покупка и управление подпиской подставляются отсюда:
                // сам интерфейс про RevenueCat не знает и линковать его не
                // должен — ту же библиотеку линкует расширение виджета.
                .paywallStore(Self.usesRevenueCat ? entitlements : nil)
                .purchaseScreens(customerCenter: Self.customerCenter)
                .task { entitlements.configure(apiKey: Self.revenueCatKey) }
        }
    }
}
