import Foundation
import DeepamCore
import Observation
import RevenueCat

/// Доступ к платному, подтверждённый RevenueCat.
///
/// Заменяет заглушку `StubEntitlements`, ради которой и заводился протокол
/// `EntitlementStore`: экраны обращаются к абстракции и не знают, кто её
/// выполняет.
///
/// Состояние приходит потоком `customerInfoStream`, а не разовым запросом.
/// Разовый ответ устарел бы сразу: подписку могут оформить на другом устройстве,
/// вернуть деньги, или она просто закончится, пока приложение открыто.
@Observable
@MainActor
public final class RevenueCatEntitlements: EntitlementStore, PaywallStore {
    /// Идентификатор права из панели RevenueCat. Строка должна совпадать с ней
    /// посимвольно — при расхождении SDK молча вернёт «не куплено».
    public static let entitlement = "deepam_pro"

    public private(set) var isSubscribed = false

    /// Снимок подписки для виджета и отката оформления. `nil`, пока RevenueCat
    /// не ответил: по отсутствию ответа ничего снимать нельзя, иначе подписчик
    /// без сети на запуске терял бы свой фон.
    public private(set) var proStatus: ProStatus?

    /// Пришёл ли уже первый ответ.
    ///
    /// Без этого флага пейволл мигает на запуске: пока SDK проверяет права,
    /// подписки формально «нет», и экран успевает показаться и тут же исчезнуть.
    public private(set) var isLoaded = false

    /// Последняя ошибка, которую стоит показать человеку. Ошибки самого потока
    /// сюда не попадают — сеть отвалилась, значит покажем прежнее состояние.
    public private(set) var lastError: String?

    /// Тарифы с ценами из магазина. Пусто, пока предложение не приехало.
    public private(set) var plans: [PaywallPlan] = []

    public private(set) var isPurchasing = false

    /// Задача жива столько же, сколько сам объект: отменять её в `deinit` не
    /// надо — он не на главном акторе, а обращаться к свойству оттуда нельзя.
    private var listener: Task<Void, Never>?

    /// Пакеты предложения по периодам. Держим их, а не кладём в `PaywallPlan`:
    /// модель тарифа читает интерфейс, и знать про типы RevenueCat ей незачем.
    private var packages: [PaywallPlan.Period: Package] = [:]

    public private(set) var welcomeOffer: WelcomeOffer?

    /// Пакет со скидкой. Идентификатор задан в предложении RevenueCat руками —
    /// стандартного для «годового со скидкой» там нет.
    private var welcomePackage: Package?
    private static let welcomePackageID = "welcome"

    public init() {}

    /// Годится ли ключ для этой сборки.
    ///
    /// Ключ тестового магазина (`test_`) в сборке Release — гарантированное
    /// падение на старте: SDK нарочно вызывает `fatalError`, чтобы такой ключ не
    /// уехал в App Store (`Configuration.checkForSimulatedStoreAPIKeyInRelease`).
    /// Проверка сидит внутри `Purchases.configure`, поэтому единственный способ
    /// не упасть — не звать её вовсе.
    ///
    /// В Debug тестовый ключ штатен: там эта защита выключена, и покупки идут
    /// мимо App Store, не требуя заведённых товаров.
    ///
    /// `nonisolated`, потому что ответ нужен точке входа до всякого состояния —
    /// при вычислении статического поля, а туда изоляция класса не пускает.
    public nonisolated static func accepts(apiKey: String) -> Bool {
        // Пустой ключ — приложение RevenueCat ещё не заведено: SDK не поднимается вовсе.
        guard !apiKey.isEmpty else { return false }
        #if DEBUG
        return true
        #else
        return !apiKey.hasPrefix("test_")
        #endif
    }

    /// Настройка SDK и подписка на изменения.
    ///
    /// Ключ публичный: он вшивается в приложение по замыслу RevenueCat и
    /// секретом не является — покупки всё равно проверяются на их сервере по
    /// чеку от Apple.
    public func configure(apiKey: String) {
        // Негодный ключ — не беда: приложение работает целиком, закрыто только
        // платное. Это лучше, чем падение при запуске.
        guard Self.accepts(apiKey: apiKey) else {
            isLoaded = true
            return
        }
        guard !Purchases.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(with: Configuration.Builder(withAPIKey: apiKey).build())
        Self.applyMetaAttribution()
        listen()
        Task { await loadPlans() }
    }

    /// Связь покупок с рекламой Meta. Оплату после триала и продления Meta SDK
    /// не видит — они случаются без приложения, — их шлёт в Meta сам
    /// RevenueCat (интеграция в его панели). Чтобы Meta отнесла их к той же
    /// установке, что и события SDK, RevenueCat нужен анонимный идентификатор
    /// Meta и идентификаторы устройства.
    ///
    /// Зовётся только для тех, кто разрешил отслеживание: передать данные в
    /// Meta для оценки рекламы без согласия Apple считает трекингом.
    /// Приложение может позвать это раньше, чем поднимет RevenueCat, — тогда
    /// идентификатор подождёт до `configure`.
    public static func shareMetaAttribution(anonymousID: String) {
        pendingMetaID = anonymousID
        applyMetaAttribution()
    }

    private static var pendingMetaID: String?

    private static func applyMetaAttribution() {
        guard Purchases.isConfigured, let id = pendingMetaID else { return }
        Purchases.shared.attribution.setFBAnonymousID(id)
        Purchases.shared.attribution.collectDeviceIdentifiers()
    }

    /// Тянет предложение — текущее или названное в рассылке — и раскладывает
    /// его по периодам.
    ///
    /// Набор тарифов задаёт предложение в панели RevenueCat — здесь ни цен, ни
    /// идентификаторов товаров нет намеренно. Идентификатор в коде означал бы
    /// выпуск приложения ради смены товара, а предложение затем и придумано,
    /// чтобы менять состав без релиза.
    ///
    /// Обратная сторона: тариф без пакета в предложении на экран не попадёт —
    /// молча, потому что для приложения его просто нет. Если тарифа не хватает,
    /// смотреть надо туда, и в первую очередь на идентификатор: `offering.annual`
    /// находит пакет только по стандартному `$rc_annual`. Годовой у нас уже
    /// пропадал ровно из-за чужого идентификатора в этом поле.
    ///
    /// Молчит при отказе намеренно. Не приехали цены — платный экран покажет
    /// это сам, ожиданием; вешать поверх онбординга алерт «нет сети» в момент,
    /// когда человек ничего не просил, незачем.
    public func loadPlans(offering identifier: String?) async {
        guard Purchases.isConfigured,
              let offerings = try? await Purchases.shared.offerings(),
              let offering = identifier.flatMap(offerings.offering(identifier:)) ?? offerings.current
        else { return }

        var found: [PaywallPlan.Period: Package] = [:]
        var list: [PaywallPlan] = []
        for (period, package) in [(PaywallPlan.Period.week, offering.weekly),
                                  (.month, offering.monthly),
                                  (.year, offering.annual)] {
            guard let package else { continue }
            found[period] = package
            let product = package.storeProduct
            list.append(PaywallPlan(
                period: period,
                price: product.localizedPriceString,
                // Вводный период бывает не у всех и не всегда: по правилам
                // Apple он даётся один раз на группу подписок, и вернувшемуся
                // человеку магазин его уже не отдаст. Поэтому спрашиваем
                // магазин, а не считаем по названию тарифа.
                trialDays: Self.trialDays(of: product)
            ))
        }
        packages = found
        plans = list
        await loadWelcomeOffer(from: offering)
    }

    /// Длина бесплатного вводного периода в днях; 0, если его нет. Считается по тому,
    /// что отдал магазин: «3 дня», «1 неделя», «1 месяц» — всё приводится к дням.
    static func trialDays(of product: StoreProduct) -> Int {
        guard let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else { return 0 }
        let unit: Int
        switch intro.subscriptionPeriod.unit {
        case .day: unit = 1
        case .week: unit = 7
        case .month: unit = 30
        case .year: unit = 365
        @unknown default: unit = 1
        }
        return max(1, intro.numberOfPeriods) * intro.subscriptionPeriod.value * unit
    }

    /// Скидка показывается, только если Apple точно её даст.
    ///
    /// Вводное предложение — одно на группу подписок за всю жизнь Apple ID:
    /// кто уже брал бесплатную неделю, купил бы этот же годовой за полную
    /// цену, а экран обещал бы скидку. Поэтому ответ магазина «неизвестно»
    /// здесь равен «нет».
    private func loadWelcomeOffer(from offering: Offering) async {
        guard let package = offering.package(identifier: Self.welcomePackageID),
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .payUpFront
        else { return }
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: package.storeProduct)
        guard eligibility == .eligible else { return }
        welcomePackage = package
        welcomeOffer = WelcomeOffer(introPrice: intro.localizedPriceString,
                                    regularPrice: package.storeProduct.localizedPriceString)
    }

    /// Покупка выбранного тарифа.
    public func purchase(_ plan: PaywallPlan) async {
        guard let package = packages[plan.period] else { return }
        await buy(package, period: plan.period)
    }

    /// Годовой со скидкой на первый год.
    public func purchaseWelcome() async {
        guard let welcomePackage else { return }
        await buy(welcomePackage, period: .year)
    }

    private func buy(_ package: Package, period: PaywallPlan.Period) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            // Отмену не трогаем вовсе: ни ошибки, ни смены состояния.
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
            log(result.customerInfo, period: period, product: package.storeProduct)
        } catch {
            lastError = message(for: error)
            // Отмена сюда тоже приходит ошибкой, но `message` её гасит: передумал
            // не значит «не смог».
            if lastError != nil {
                EventLog.log(.purchaseFailed(period, reason: reason(for: error)))
            }
        }
    }

    /// Триал или оплата — решает не тариф, а ответ RevenueCat.
    ///
    /// По тарифу судить нельзя: бесплатная неделя даётся один раз на группу
    /// подписок, и вернувшийся человек покупает тот же годовой уже за деньги.
    ///
    /// Сумма — то, что списали сейчас: у годового со скидкой это цена первого
    /// года, а не обычная.
    private func log(_ info: CustomerInfo, period: PaywallPlan.Period, product: StoreProduct) {
        let entitlement = info.entitlements[Self.entitlement]
        if entitlement?.periodType == .trial {
            EventLog.log(.trialStart(period, productID: product.productIdentifier))
        } else {
            let charged = entitlement?.periodType == .intro
                ? product.introductoryDiscount?.price ?? product.price
                : product.price
            EventLog.log(.purchase(period, productID: product.productIdentifier,
                                   price: charged, currency: product.currencyCode))
        }
    }

    /// Причина отказа для отчёта. Текст у RevenueCat английский и не
    /// переводится — его можно читать прямо в GA4, без таблицы кодов. Обрезка
    /// — потому что длиннее 100 символов GA4 значение параметра не примет.
    private func reason(for error: Error) -> String {
        let text = (error as? RevenueCat.ErrorCode)?.description ?? "other"
        return String(text.prefix(100))
    }

    public func restorePurchases() async {
        await restore()
    }

    private func listen() {
        listener?.cancel()
        listener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        let pro = info.entitlements[Self.entitlement]
        isSubscribed = pro?.isActive == true
        // Права в ответе нет вовсе — подписки не было никогда. Это тоже знание,
        // а не его отсутствие: такой ответ спокойно пишется в снимок.
        proStatus = pro.map {
            ProStatus(isActive: $0.isActive, expiresAt: $0.expirationDate, willRenew: $0.willRenew,
                      isTrial: $0.periodType == .trial)
        } ?? ProStatus.noSubscription
        isLoaded = true
    }

    /// Восстановление покупок.
    ///
    /// Нужно не только после переустановки: подписку могли оформить с другого
    /// устройства на тот же Apple ID, и без восстановления она здесь не видна.
    public func restore() async {
        lastError = nil
        do {
            apply(try await Purchases.shared.restorePurchases())
        } catch {
            lastError = message(for: error)
        }
    }

    /// Человекочитаемая причина отказа.
    ///
    /// Отмена — не ошибка: человек передумал, и ругаться на него не за что.
    private func message(for error: Error) -> String? {
        guard let error = error as? RevenueCat.ErrorCode else { return error.localizedDescription }
        return error == .purchaseCancelledError ? nil : error.localizedDescription
    }

}
