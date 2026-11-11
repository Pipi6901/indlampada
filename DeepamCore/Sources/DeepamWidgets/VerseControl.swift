#if os(iOS)
import AppIntents
import DeepamCore
import SwiftUI
import WidgetKit

/// Кнопка в Пункте управления.
///
/// Появилась в iOS 18 — раньше добавлять туда что-то своё было нельзя вовсе.
/// Минимальная версия приложения ниже, поэтому и сам контрол, и всё, чем он
/// пользуется, закрыты проверкой доступности: на iOS 17 расширение просто
/// соберётся без него.
///
/// Кнопка ведёт в приложение, а не показывает стих на месте. Пункт управления
/// закрывается от любого касания, и текст в нём человек прочитать не успеет;
/// зато подпись под кнопкой — это ссылка на сегодняшний стих, и по ней видно,
/// что именно откроется.
@available(iOS 18.0, *)
public struct VerseControl: ControlWidget {
    public init() {}

    /// Подписи берутся из настройки приложения, а если человек до неё не дошёл —
    /// из языка устройства. Своего выбора языка у расширения нет, и статические
    /// строки остались бы русскими для всех.
    private var l10n: L10n { L10n(AppSettings().language ?? .detect()) }

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "DeepamVerseControl",
                                   provider: VerseControlProvider()) { reference in
            ControlWidgetButton(action: OpenVerseIntent()) {
                Label(reference, systemImage: "flame.fill")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: l10n[.controlDisplayName]))
        .description(LocalizedStringResource(stringLiteral: l10n[.controlDescription]))
    }
}

/// Значение для кнопки — ссылка на стих дня.
///
/// Система спрашивает его редко и сама решает когда, поэтому тяжёлой работы
/// здесь быть не должно: один разбор корпуса и выход.
@available(iOS 18.0, *)
struct VerseControlProvider: ControlValueProvider {
    /// Что видно в галерее контролов, пока настоящее значение не посчитано.
    var previewValue: String {
        L10n(AppSettings().language ?? .detect())[.demoReference]
    }

    func currentValue() async throws -> String {
        dailyCard(for: .now)?.reference ?? previewValue
    }
}

/// Действие кнопки: открыть Deepam.
///
/// Тело пустое намеренно — вся работа в `openAppWhenRun`. Показывать стих
/// изнутри Пункта управления некуда, а приложение и так открывается на
/// «Сегодня», где стих дня и лежит.
@available(iOS 18.0, *)
struct OpenVerseIntent: AppIntent {
    static let title: LocalizedStringResource = "Verse of the day"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}
#endif
