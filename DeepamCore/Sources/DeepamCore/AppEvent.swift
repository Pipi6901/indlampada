import Foundation

/// Событие продуктовой аналитики.
///
/// Пакет не знает, куда события уходят: приёмники ставит приложение — сейчас
/// это Firebase (GA4), Amplitude и Meta. Каждый приёмник сам решает, что из
/// набора ему нужно: Meta получает только то, на чём учится реклама, и
/// никогда — ответы онбординга и причины отмены. Расширение виджета SDK не
/// линкует, тесты и предпросмотры их не поднимают, и там события просто
/// никуда не идут.
///
/// Набор закрытый — ровно столько, чтобы посчитать воронку «онбординг →
/// пейволл → триал → оплата», главную метрику продукта (сколько поверхностей
/// человек включил) и понять, почему уходят. Текст стихов сюда не попадает.
///
/// Ответы онбординга — «зачем» и состояния — отправляются по решению от
/// 26.10: без них не видно, кто платит. Состояния вроде «тревоги» близки к
/// данным о здоровье, поэтому они названы в политике конфиденциальности и в
/// анкете App Store прямо, а сбор выключается на «Виде».
///
/// Имена — в snake_case, как принято в GA4: там же их и будут искать.
public enum AppEvent: Sendable, Equatable {
    /// Показан шаг онбординга. Номер с нуля и имя: воронка читается без
    /// таблицы соответствий и не ломается, если шаги переставят.
    case onboardingStep(index: Int, name: String)
    /// Онбординг пройден: пейволл в его конце закрыт, куплено или нет.
    case onboardingComplete
    /// Ответ онбординга: вопрос (`goal` или `theme`) и выбранный вариант.
    /// Событие на каждый вариант — так в GA4 строится сегмент «кто выбрал X».
    /// До 1.0.2 вместо `goal` был `intent` с мультивыбором. Часы в ленте с
    /// ветки «Меньше ленты» не уходят: экран обещает, что ответ останется на
    /// телефоне.
    case onboardingAnswer(question: String, answer: String)
    /// Причина отмены: своим листом после отмены триала или опросом в
    /// управлении подпиской RevenueCat. `skip` — лист закрыли без ответа.
    case cancelReason(reason: String, source: String, wasTrial: Bool)
    /// Показан платный экран, откуда его открыли и какой версией: ветка
    /// онбординга (`comfort`, `daily`, `feed`, `beauty`), `pick` — с плашкой
    /// «Твой выбор», `generic` — без того и другого. `nil` — у экрана нет
    /// вариантов (скидка после пейволла).
    case paywallView(PaywallSource, variant: String? = nil)
    /// Начат бесплатный период.
    case trialStart(PaywallPlan.Period, productID: String)
    /// Оплата сразу, без триала. Цена числом и валюта — их ждёт отчёт о доходе
    /// в GA4, готовая строка вроде «$24.99» ему не годится.
    case purchase(PaywallPlan.Period, productID: String, price: Decimal, currency: String?)
    /// Покупка не прошла по вине магазина, а не потому, что человек передумал.
    /// Без этого события технический отказ в отчёте неотличим от нежелания
    /// платить.
    case purchaseFailed(PaywallPlan.Period, reason: String)
    /// Виджет поставили или убрали. Узнаём при открытии приложения — см.
    /// `WidgetCensus`.
    case widgetAdded(kind: String, family: String)
    case widgetRemoved(kind: String, family: String)
    /// Ответ на системный запрос уведомлений и где его задали.
    case pushPermission(granted: Bool, source: String)
    /// Открыли наше уведомление. Имя не `notification_open`: оно занято
    /// самим Firebase и молча отбрасывается.
    case pushOpened(ReminderKind)
    /// Открыли рассылку из консоли Firebase. Имя кампании — как в консоли.
    case campaignOpened(String)
    /// Показана страница «Что нового» после обновления. Номер с нуля и имя:
    /// icons, pictures, daily.
    case whatsNewStep(index: Int, name: String)
    /// Переключили «Новости и обновления». `source`: whats_new или places.
    case promoOptIn(on: Bool, source: String)
    /// Попросили оценку: `auto` — системное окно (покажет ли его iOS, не
    /// узнать), `look` — тап по строке «Оценить Deepam».
    case reviewPrompt(source: String)

    public var name: String {
        switch self {
        case .onboardingStep: "onboarding_step"
        case .onboardingComplete: "onboarding_complete"
        case .onboardingAnswer: "onboarding_answer"
        case .cancelReason: "cancel_reason"
        case .paywallView: "paywall_view"
        case .trialStart: "trial_start"
        case .purchase: "purchase"
        case .purchaseFailed: "purchase_failed"
        case .widgetAdded: "widget_added"
        case .widgetRemoved: "widget_removed"
        case .pushPermission: "push_permission"
        case .pushOpened, .campaignOpened: "push_opened"
        case .reviewPrompt: "review_prompt"
        case .whatsNewStep: "whats_new_step"
        case .promoOptIn: "promo_optin"
        }
    }

    public var parameters: [String: EventValue] {
        switch self {
        case let .onboardingStep(index, name):
            return ["step": .int(index), "step_name": .text(name)]
        case .onboardingComplete:
            return [:]
        case let .onboardingAnswer(question, answer):
            return ["question": .text(question), "answer": .text(answer)]
        case let .cancelReason(reason, source, wasTrial):
            return ["reason": .text(reason), "source": .text(source), "was_trial": .int(wasTrial ? 1 : 0)]
        case let .paywallView(source, variant):
            guard let variant else { return ["source": .text(source.rawValue)] }
            return ["source": .text(source.rawValue), "variant": .text(variant)]
        case let .trialStart(period, productID):
            return ["plan": .text(period.rawValue), "product_id": .text(productID)]
        case let .purchase(period, productID, price, currency):
            var parameters: [String: EventValue] = [
                "plan": .text(period.rawValue),
                "product_id": .text(productID),
                "value": .double(NSDecimalNumber(decimal: price).doubleValue),
            ]
            // Без валюты GA4 сумму не учтёт, но и выдумывать её нельзя:
            // доллары там, где списали рубли, исказили бы доход хуже пропуска.
            if let currency { parameters["currency"] = .text(currency) }
            return parameters
        case let .purchaseFailed(period, reason):
            return ["plan": .text(period.rawValue), "reason": .text(reason)]
        case let .widgetAdded(kind, family), let .widgetRemoved(kind, family):
            return ["kind": .text(kind), "family": .text(family)]
        case let .pushPermission(granted, source):
            return ["granted": .int(granted ? 1 : 0), "source": .text(source)]
        case let .pushOpened(kind):
            return ["kind": .text(kind.rawValue)]
        case let .campaignOpened(campaign):
            return ["kind": .text("campaign"), "campaign": .text(campaign)]
        case let .reviewPrompt(source):
            return ["source": .text(source)]
        case let .whatsNewStep(index, name):
            return ["step": .int(index), "step_name": .text(name)]
        case let .promoOptIn(on, source):
            return ["granted": .int(on ? 1 : 0), "source": .text(source)]
        }
    }
}

/// Значение параметра. Firebase принимает строки и числа — больше ничего и не
/// нужно.
public enum EventValue: Sendable, Equatable {
    case text(String)
    case int(Int)
    case double(Double)
}

/// Откуда открыли платный экран.
///
/// Нужен, чтобы видеть, какой замок продаёт: пейволл в конце онбординга видят
/// все, а до замков доходят те, кто уже чего-то захотел.
public enum PaywallSource: String, Sendable {
    case onboarding
    /// Тап по закрытому StandBy.
    case standBy = "standby"
    /// Лист «Подписка закончилась».
    case expired
    /// Платный набор или картинка на «Виде».
    case look
    /// Платная поверхность на «Местах».
    case places
    case font
    case icon
    /// Второй шанс после закрытого пейволла онбординга: годовой со скидкой.
    case welcome
    /// Тап по рассылке с ключом `paywall` или `offering`.
    case push
    /// Платная иконка или картинка на экране «Что нового».
    case whatsNew = "whats_new"
}

/// Что человек тапнул, прежде чем упереться в замок. Платный экран
/// показывает это над заголовком: он продаёт не «подписку вообще», а то,
/// чего человек только что захотел.
public struct PaywallPick: Sendable, Hashable {
    public let unlock: PaywallUnlock
    public let name: String

    public init(_ unlock: PaywallUnlock, name: String) {
        self.unlock = unlock
        self.name = name
    }
}

/// Куда уходят события.
@MainActor
public protocol EventSink {
    func log(_ event: AppEvent)
    /// Свойство человека, а не события: по нему режутся все отчёты сразу.
    func setUserProperty(_ value: String?, forName name: String)
    /// Переключатель «Помогать улучшать Deepam». Выключен — приёмник не
    /// собирает и не отправляет ничего, включая то, что SDK пишет сам.
    func setCollectionEnabled(_ enabled: Bool)
}

/// Точка, через которую экраны отдают события.
///
/// Приёмники ставит точка входа до первого экрана, каждое событие получают
/// все. Нет ни одного — события теряются молча: так и задумано для тестов,
/// предпросмотров и расширения виджета.
@MainActor
public enum EventLog {
    public static var sinks: [any EventSink] = []

    public static func log(_ event: AppEvent) {
        for sink in sinks { sink.log(event) }
    }

    /// Сколько виджетов стоит сейчас — главная метрика продукта, поэтому она
    /// свойство человека: по ней делится удержание и конверсия.
    public static func setWidgetCount(_ count: Int) {
        setUserProperty(String(count), forName: "widget_count")
    }

    public static func setCollectionEnabled(_ enabled: Bool) {
        for sink in sinks { sink.setCollectionEnabled(enabled) }
    }

    /// Свойства для отчётов и для таргета кампаний Firebase Messaging: язык
    /// приложения, включён ли стих дня, есть ли Pro.
    public static func setUserProperty(_ value: String?, forName name: String) {
        for sink in sinks { sink.setUserProperty(value, forName: name) }
    }
}
