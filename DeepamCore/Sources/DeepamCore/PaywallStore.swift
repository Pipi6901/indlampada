import Foundation
import Observation

/// Магазин для платного экрана: цены и покупка.
///
/// Отдельно от `EntitlementStore` по той же причине, по какой тот вообще
/// существует: право «куплено или нет» нужно всему приложению, а цены и кнопка
/// «купить» — одному экрану. Разведены, чтобы заглушке прав не приходилось
/// притворяться магазином.
///
/// Выполняет протокол слой RevenueCat. Сам интерфейс о нём не знает: ту же
/// библиотеку линкует расширение виджета, и SDK уехал бы туда следом.
@MainActor
public protocol PaywallStore: AnyObject, Observable {
    /// Тарифы с ценами, как их отдал магазин. Пусто — ещё не приехали.
    ///
    /// Пустой список это не ошибка: сеть медленная, а на территории может не
    /// оказаться части тарифов. Экран показывает то, что есть.
    var plans: [PaywallPlan] { get }

    /// Идёт ли покупка прямо сейчас. Нужно, чтобы кнопка не давала нажать
    /// себя дважды: второе нажатие открывает второй системный лист.
    var isPurchasing: Bool { get }

    /// Последняя ошибка, которую стоит показать. Отмена покупки сюда не
    /// попадает: человек передумал, и ругаться на него не за что.
    var lastError: String? { get }

    /// Запросить цены. Экран зовёт это при появлении: к запуску приложения они
    /// могли не успеть, а платный экран без цен бесполезен.
    ///
    /// - Parameter offering: предложение RevenueCat. `nil` — текущее; другое
    ///   приходит из рассылки (ключ `offering`), например акция к Чёрной
    ///   пятнице. Нет такого предложения — показывается текущее.
    func loadPlans(offering: String?) async
    func purchase(_ plan: PaywallPlan) async
    func restorePurchases() async

    /// Скидка после закрытого пейволла онбординга. `nil` — её нет в
    /// предложении RevenueCat или человеку вводная цена уже не положена: тогда
    /// экран со скидкой не показывается вовсе, а не обещает то, чего Apple не
    /// даст.
    var welcomeOffer: WelcomeOffer? { get }
    func purchaseWelcome() async
}

/// Годовой с оплатой первого года сразу и со скидкой. Цены — готовыми
/// строками магазина, по той же причине, что в `PaywallPlan`.
public struct WelcomeOffer: Sendable, Hashable {
    /// Цена первого года, например «$17.49».
    public let introPrice: String
    /// Обычная цена года, с которой подписка продлится, — «$24.99».
    public let regularPrice: String

    public init(introPrice: String, regularPrice: String) {
        self.introPrice = introPrice
        self.regularPrice = regularPrice
    }
}

extension PaywallStore {
    /// Цены текущего предложения.
    public func loadPlans() async { await loadPlans(offering: nil) }
}
