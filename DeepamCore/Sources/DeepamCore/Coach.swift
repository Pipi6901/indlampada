import Foundation
import Observation

/// Обучение действием: подсветить место на экране, сказать одну фразу и ждать,
/// пока человек сам это сделает.
///
/// Не картинки с описанием возможностей и не текст, который пролистывают.
/// Первый шаг проходится свайпом, второй — выбором оформления: пока человек не
/// сделал, тур не идёт дальше.
///
/// Шаги живут здесь, а не в интерфейсе, ровно по одной причине: почти каждый
/// ждёт изменения настроек, а настройки — это модель. Держать условия перехода
/// рядом с вёрсткой значило бы, что экран должен знать, чего от него ждут.
@Observable
@MainActor
public final class Coach {
    public enum Step: String, Sendable, Hashable, CaseIterable, Identifiable {
        /// «Сегодня»: свайп меняет стих.
        case swipe
        /// «Вид»: чем отличаются три области.
        case areas
        /// «Вид»: выбрать оформление приложения — цвет или картинку.
        case appStyle
        /// «Вид»: переключиться на область виджетов.
        ///
        /// Отдельный шаг, а не половина следующего: подсказка обязана смениться
        /// в момент, когда человек сделал то, о чём его просили. Иначе он
        /// переключился, а экран говорит с ним прежней фразой — и непонятно,
        /// засчитано ли.
        case switchToWidgets
        /// «Вид»: то же оформление для виджетов, чтобы стало видно — оно своё.
        case widgetStyle
        /// «Места»: плитка открывает инструкцию.
        case places
        /// «Места»: переключатель отмечает, что поверхность поставлена.
        case markDone

        public var id: String { rawValue }

        /// На какой вкладке проходится шаг. Тур сам переключает её: иначе
        /// подсказка указывала бы на то, чего сейчас нет на экране.
        public var tab: String {
            switch self {
            case .swipe: "today"
            case .areas, .appStyle, .switchToWidgets, .widgetStyle: "look"
            case .places, .markDone: "places"
            }
        }

        /// Шаг проходится действием, а не кнопкой «Дальше».
        ///
        /// У объяснительных шагов действия нет, и запирать человека на них
        /// нельзя — он и так уже прочитал.
        public var needsAction: Bool { self != .areas }

        public var captionKey: L10n.Key {
            switch self {
            case .swipe: .coachSwipe
            case .areas: .coachAreas
            case .appStyle: .coachAppStyle
            case .switchToWidgets: .coachSwitchToWidgets
            case .widgetStyle: .coachWidgetStyle
            case .places: .coachPlaces
            case .markDone: .coachMarkDone
            }
        }
    }

    public private(set) var step: Step?

    private let settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var isRunning: Bool { step != nil }

    /// Запускается один раз после онбординга. Второй раз тур не показывается:
    /// подсветка поверх экрана, который человек уже знает, — это помеха.
    ///
    /// Идемпотентно: зовётся по появлению вкладок, а появиться они могут снова —
    /// без проверки на уже идущий тур повторный вызов отбросил бы человека на
    /// первый шаг.
    public func startIfNeeded() {
        guard !settings.hasSeenCoach, step == nil else { return }
        step = .swipe
    }

    public func advance() {
        guard let current = step, let index = Step.allCases.firstIndex(of: current) else { return }
        let next = Step.allCases.index(after: index)
        if next < Step.allCases.endIndex {
            step = Step.allCases[next]
        } else {
            finish()
        }
    }

    /// Досрочный выход. Тур считается пройденным: человек отказался, и
    /// предлагать снова — навязчивость.
    public func finish() {
        step = nil
        settings.hasSeenCoach = true
    }

    /// Шаг выполнен тем действием, которого он ждал.
    ///
    /// Отдельно от `advance`, чтобы вызывающему не приходилось проверять, тот ли
    /// сейчас шаг: экран просто сообщает, что произошло.
    public func completed(_ done: Step) {
        guard step == done else { return }
        advance()
    }
}
