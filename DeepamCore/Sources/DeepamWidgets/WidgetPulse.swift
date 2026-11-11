import Foundation
import DeepamCore

/// «Пульс» виджета: раз в сутки виджет сам сообщает в GA4, что он стоит.
///
/// Без этого удержание видно только по открытиям приложения, а у Deepam
/// продукт — виджет: кто читает стих на экране блокировки и приложение не
/// открывает, во всех отчётах выглядел бы ушедшим. Firebase в расширение не
/// тянется (память виджета ограничена), поэтому событие уходит одним
/// запросом через Measurement Protocol — от имени той же установки, что и
/// события приложения.
///
/// Выключенная статистика на «Виде» выключает и пульс.
enum WidgetPulse {
    /// Секрет Measurement Protocol (GA4 → Администратор → Потоки данных →
    /// поток iOS → Секретные ключи Measurement Protocol, псевдоним
    /// widget-pulse).
    ///
    /// В git его нет: он лежит защищённой переменной `GA_MP_SECRET` в
    /// Codemagic, при сборке подставляется в `WidgetInfo.plist`, а отсюда
    /// читается. Локальная сборка без переменной даёт пустую строку — и пульс
    /// просто молчит. В готовом приложении ключ всё равно виден: у
    /// Measurement Protocol иначе нельзя, худшее, что с ним можно сделать, —
    /// прислать лишние события, и тогда его перевыпускают.
    static var apiSecret: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "GAMeasurementSecret") as? String ?? ""
        // Не раскрытая сборкой подстановка — то же, что пустота.
        return value.hasPrefix("$(") ? "" : value
    }

    static func beat(family: String, now: Date = .now) {
        guard !apiSecret.isEmpty else { return }
        let settings = AppSettings()
        // Идентификаторы установки и приложения записывает приложение, когда
        // Firebase поднят (нужен `GoogleService-Info.plist`). Нет их — пульсу
        // слать некуда.
        guard settings.analyticsEnabled,
              let instance = settings.analyticsInstanceID,
              let appID = settings.analyticsAppID else { return }
        let day = VerseEngine.dayIndex(for: now)
        guard settings.lastPulseDay != day else { return }
        settings.lastPulseDay = day

        var components = URLComponents(string: "https://www.google-analytics.com/mp/collect")
        components?.queryItems = [
            URLQueryItem(name: "firebase_app_id", value: appID),
            URLQueryItem(name: "api_secret", value: apiSecret),
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "app_instance_id": instance,
            "events": [["name": "widget_alive", "params": ["family": family]]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
}
