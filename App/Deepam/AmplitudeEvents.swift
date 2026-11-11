import AmplitudeSwift
import Foundation
import DeepamCore

/// Приёмник событий для Amplitude — удержание и когорты.
///
/// События те же, что уходят в GA4, с теми же именами и параметрами: два
/// отчёта об одном и том же не должны расходиться в словах. Сверху Amplitude
/// сам пишет сессии и установки/открытия — по ним и считается удержание.
///
/// Без IDFA (его SDK и не берёт), без города и оператора: для решений
/// хватает страны. Ключ проекта — в `DeepamInfo.plist`; пусто — Amplitude
/// в этой сборке нет.
@MainActor
final class AmplitudeEventSink: EventSink {
    private let amplitude: Amplitude

    init?(enabled: Bool) {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AmplitudeAPIKey") as? String,
              !key.isEmpty else { return nil }
        amplitude = Amplitude(configuration: Configuration(
            apiKey: key,
            optOut: !enabled,
            trackingOptions: TrackingOptions().disableTrackCity().disableTrackDMA().disableTrackCarrier(),
            autocapture: [.sessions, .appLifecycles]
        ))
    }

    func log(_ event: AppEvent) {
        amplitude.track(eventType: event.name, eventProperties: event.parameters.mapValues(\.anyValue))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        let identify = Identify()
        if let value {
            identify.set(property: name, value: value)
        } else {
            identify.unset(property: name)
        }
        amplitude.identify(identify: identify)
    }

    func setCollectionEnabled(_ enabled: Bool) {
        amplitude.optOut = !enabled
    }
}
