// AdSupport подключается ради RevenueCat: IDFA разрешивших он читает через
// него, а сам фреймворк не линкует.
import AdSupport
import AppTrackingTransparency
import FacebookCore
import DeepamCore
import DeepamPurchases
import UIKit

/// Реклама в Meta (Facebook, Instagram): установки и события, на которых
/// учатся кампании. Оптимизация — по старту триала.
///
/// SDK поднимается после ответа на ATT, а не при запуске: тогда установка
/// уходит в Meta уже с ответом, и у разрешивших — с рекламным
/// идентификатором. Окно спрашивает онбординг (`AdTracking`), до пейволла.
/// Кто обновился с прежней версии, онбординг не проходит и окна не видит:
/// эти люди пришли не из рекламы, и SDK у них поднимается сразу, без
/// идентификатора. Флаг «отслеживание разрешено» SDK 17+ читает из системы
/// сам — ставить его руками не нужно.
///
/// Автологирование SDK выключено (`DeepamInfo.plist`): иначе он сам пишет
/// покупки из StoreKit, а их же шлёт RevenueCat, и Meta считает оплату
/// дважды — общего идентификатора события у них нет. Поэтому активацию
/// приложения засчитываем сами, при каждом выходе на передний план.
///
/// App ID и токен клиента — в `DeepamInfo.plist`. Пусто — Meta в этой
/// сборке нет совсем, и шага ATT в онбординге тоже.
@MainActor
enum MetaAds {
    /// Ключи Meta вписаны и есть текст окна отслеживания. Без текста системное
    /// окно ATT роняет приложение, а в 1.0.2 его нарочно нет — см.
    /// `TRACKING` в `make_project.py`. Ключи без текста — значит, Meta не
    /// поднимается вовсе, а не падает.
    private static var isConfigured: Bool {
        ["FacebookAppID", "FacebookClientToken", "NSUserTrackingUsageDescription"].allSatisfy {
            !((Bundle.main.object(forInfoDictionaryKey: $0) as? String) ?? "").isEmpty
        }
    }

    private static var sink: MetaEventSink?

    static func prepare(_ application: UIApplication,
                        launchOptions: [UIApplication.LaunchOptionsKey: Any]?,
                        settings: AppSettings) {
        guard isConfigured else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined, !settings.hasSeenOnboarding else {
            start(application, launchOptions: launchOptions, settings: settings)
            return
        }
        AdTracking.prompt = { @MainActor in
            _ = await ATTrackingManager.requestTrackingAuthorization()
            AdTracking.prompt = nil
            start(application, launchOptions: nil, settings: settings)
            // Приложение уже на экране, и уведомления о выходе на передний
            // план не будет до следующего открытия — иначе установка до Meta
            // сразу не дойдёт.
            sink?.activate()
        }
    }

    private static func start(_ application: UIApplication,
                              launchOptions: [UIApplication.LaunchOptionsKey: Any]?,
                              settings: AppSettings) {
        guard sink == nil else { return }
        Settings.shared.isAutoLogAppEventsEnabled = false
        _ = ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        let sink = MetaEventSink(enabled: settings.analyticsEnabled)
        self.sink = sink
        EventLog.sinks.append(sink)
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MetaAds.sink?.activate() }
        }
        // Продления и оплату после триала шлёт в Meta уже RevenueCat — ему
        // нужен тот же анонимный идентификатор. Только разрешившим.
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            RevenueCatEntitlements.shareMetaAttribution(anonymousID: AppEvents.shared.anonymousID)
        }
    }
}

/// Что из событий уходит в Meta. Только то, на чём учится реклама: конец
/// онбординга, показ пейволла, триал, оплата и поставленный виджет. Ответы
/// онбординга, причины отмены и всё про уведомления сюда не попадают — это
/// обещано на экране ATT.
private final class MetaEventSink: EventSink {
    private var enabled: Bool

    init(enabled: Bool) {
        self.enabled = enabled
    }

    /// Открытие приложения — по нему Meta считает установки и сессии.
    func activate() {
        if enabled { AppEvents.shared.activateApp() }
    }

    func log(_ event: AppEvent) {
        guard enabled else { return }
        let events = AppEvents.shared
        switch event {
        case .onboardingComplete:
            events.logEvent(.completedTutorial)
        case let .paywallView(source, _):
            events.logEvent(.viewedContent, parameters: [.contentType: "paywall", .contentID: source.rawValue])
        case let .trialStart(period, productID):
            events.logEvent(.startTrial, parameters: [.contentID: productID, .contentType: period.rawValue])
        case let .purchase(period, productID, price, currency):
            let parameters: [AppEvents.ParameterName: Any] = [.contentID: productID, .contentType: period.rawValue]
            // Сумма без валюты Meta не учтёт, а выдумывать валюту нельзя.
            if let currency {
                events.logEvent(.subscribe, valueToSum: NSDecimalNumber(decimal: price).doubleValue,
                                parameters: parameters.merging([.currency: currency]) { $1 })
            } else {
                events.logEvent(.subscribe, parameters: parameters)
            }
        case let .widgetAdded(_, family):
            events.logEvent(AppEvents.Name("widget_added"), parameters: [AppEvents.ParameterName("family"): family])
        default:
            break
        }
    }

    func setUserProperty(_ value: String?, forName name: String) {}

    /// «Помогать улучшать Deepam» выключает и это: один переключатель на
    /// всё, что уходит из приложения ради статистики и рекламы.
    func setCollectionEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }
}
