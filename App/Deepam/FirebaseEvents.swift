import FirebaseAnalytics
import FirebaseCore
import FirebaseMessaging
import DeepamCore
import DeepamUI
import UIKit
import UserNotifications

/// Firebase, Amplitude и Meta поднимаются здесь, а не в пакете.
///
/// Пакет линкует расширение виджета, и SDK уехали бы туда следом — а виджету
/// они не нужны, и лимит памяти у расширения жёсткий. Поэтому SDK знает только
/// приложение, а экраны отдают события через `EventLog` и о них не знают.
///
/// Делегат приложения — по образцу из консоли Firebase: настройка в
/// `didFinishLaunching` гарантированно раньше первого экрана, а значит, и
/// раньше первого события.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Без GoogleService-Info.plist Firebase не поднимается вообще: его вызовы
        // до настройки не выдают ошибки, а роняют приложение. Сборка до заведения
        // проекта Firebase должна запускаться, поэтому аналитика и рассылки в ней
        // просто молчат; всё остальное приложение работает как обычно.
        let hasFirebase = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        let settings = AppSettings()
        if hasFirebase {
            FirebaseApp.configure()
            // Рекламы в приложении нет и не будет, а своя реклама приложения идёт
            // через Meta (`MetaAds`). Согласие на рекламные цели Google снято явно,
            // чтобы он не хранил под них данные и не подмешивал наши события в
            // подбор рекламы. Само SDK взято в варианте без рекламного
            // идентификатора (`FirebaseAnalyticsCore`), так что IDFA оно не читает.
            Analytics.setConsent([
                .analyticsStorage: .granted,
                .adStorage: .denied,
                .adUserData: .denied,
                .adPersonalization: .denied,
            ])
            // Выключил «Помогать улучшать Deepam» — сбор выключается до первого
            // события, а не после него.
            Analytics.setAnalyticsCollectionEnabled(settings.analyticsEnabled)
            EventLog.sinks = [FirebaseEventSink()]
        }
        if let amplitude = AmplitudeEventSink(enabled: settings.analyticsEnabled) {
            EventLog.sinks.append(amplitude)
        }
        MetaAds.prepare(application, launchOptions: launchOptions, settings: settings)
        // Делегат — до конца запуска: если приложение подняли тапом по
        // уведомлению, ответ придёт сразу после этого метода.
        UNUserNotificationCenter.current().delegate = self
        guard hasFirebase else {
            PushToken.fetch = { .failure(PushTokenError("Firebase не настроен: нет GoogleService-Info.plist")) }
            return true
        }
        // Виджету — идентификатор установки для его ежесуточного «пульса».
        // На самом первом запуске SDK может ещё не знать его — тогда
        // запишется на следующем.
        if let id = Analytics.appInstanceID() { settings.analyticsInstanceID = id }
        settings.analyticsAppID = FirebaseApp.app()?.options.googleAppID
        // Кампании Firebase Messaging. Токен APNs Firebase перехватывает сам
        // (подмена методов делегата включена по умолчанию), регистрация нужна
        // одна. Показывать уведомления она не разрешает — это делает запрос
        // на шаге онбординга.
        _ = Messaging.messaging()
        application.registerForRemoteNotifications()
        // Токен — для пробной рассылки на свой телефон: долгое нажатие на
        // версию внизу «Вида». Обратный вызов, а не `async`: объект
        // Firebase не должен пересекать границу главного актора.
        PushToken.fetch = { await Self.pushToken() }
        return true
    }

    /// Вне главного актора: Firebase зовёт обратный вызов со своей очереди, и
    /// замыкание, унаследовавшее главный актор, упало бы на проверке изоляции.
    private nonisolated static func pushToken() async -> Result<String, PushTokenError> {
        await withCheckedContinuation { continuation in
            // Без токена APNs Firebase своего не выдаст: значит, Apple не
            // зарегистрировала устройство для пушей — дело в подписи или в
            // праве Push у App ID, а не в Firebase.
            let hasAPNs = Messaging.messaging().apnsToken != nil
            Messaging.messaging().token { token, error in
                if let token {
                    continuation.resume(returning: .success(token))
                } else {
                    let reason = error?.localizedDescription ?? "пустой ответ"
                    continuation.resume(returning: .failure(
                        PushTokenError("APNs: \(hasAPNs ? "есть" : "нет") · \(reason)")))
                }
            }
        }
    }
}

/// Открытия уведомлений — для аналитики. Обратные вызовы, а не `async`
/// варианты: так объекты фреймворка не пересекают границу главного актора.
extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        let kind = ReminderKind(identifier: request.identifier)
        // Куда вести — у своих напоминаний поверхность, у рассылок Firebase
        // ещё пейволл, предложение и вкладка; ключи описаны в `PushAction`.
        let action = PushAction(userInfo: request.content.userInfo)
        Task { @MainActor in
            if let kind {
                EventLog.log(.pushOpened(kind))
            } else if let campaign = action.campaign {
                EventLog.log(.campaignOpened(campaign))
            }
            NotificationRoute.shared.open(action)
        }
        completionHandler()
    }

    /// Стих дня пришёл, пока приложение открыто, — всё равно показать: человек
    /// мог быть на другой вкладке и ждать его.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}

/// Приёмник событий для GA4.
private struct FirebaseEventSink: EventSink {
    func log(_ event: AppEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters.mapValues(\.anyValue))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
}

extension EventValue {
    /// Значение для SDK, которые принимают словари `[String: Any]`.
    var anyValue: Any {
        switch self {
        case let .text(value): value
        case let .int(value): value
        case let .double(value): value
        }
    }
}
