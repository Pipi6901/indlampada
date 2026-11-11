import AppIntents
import DeepamCore

/// Соцсеть, в которую надо вернуться после паузы.
///
/// Список зашит в код, потому что открыть чужое приложение можно только по его
/// адресу — общего способа «открой вот это приложение» iOS не даёт. Тот же
/// подход у one sec: приложение выбирается параметром действия, а возврат
/// делает само приложение, а не системное действие «Открыть приложение».
///
/// Схемы проверять `canOpenURL` не будем: для этого их пришлось бы объявлять в
/// Info.plist, а выигрыш нулевой — человек выбирает соцсеть, которая у него
/// стоит. Если её вдруг нет, открытие просто ничего не сделает.
enum PausedApp: String, AppEnum {
    case instagram, tiktok, youtube, x, facebook, threads
    case reddit, snapchat, telegram, vk, pinterest, twitch

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "App")

    static let caseDisplayRepresentations: [PausedApp: DisplayRepresentation] = [
        .instagram: "Instagram",
        .tiktok: "TikTok",
        .youtube: "YouTube",
        .x: "X",
        .facebook: "Facebook",
        .threads: "Threads",
        .reddit: "Reddit",
        .snapchat: "Snapchat",
        .telegram: "Telegram",
        .vk: "VK",
        .pinterest: "Pinterest",
        .twitch: "Twitch",
    ]

    /// Адрес, по которому приложение открывается.
    var url: URL? {
        let scheme = switch self {
        case .instagram: "instagram"
        case .tiktok: "tiktok"
        case .youtube: "youtube"
        // X сохранила прежнюю схему: приложение переименовали, адрес нет.
        case .x: "twitter"
        case .facebook: "fb"
        // Внутреннее имя Threads со времён разработки — снаружи его не меняли.
        case .threads: "barcelona"
        case .reddit: "reddit"
        case .snapchat: "snapchat"
        case .telegram: "tg"
        case .vk: "vk"
        case .pinterest: "pinterest"
        case .twitch: "twitch"
        }
        return URL(string: scheme + "://")
    }
}

/// Действие «Verse pause» — то, что человек находит в «Командах».
///
/// Живёт в таргете приложения, а не в пакете: извлечение метаданных App Intents
/// работает по исходникам таргета, и вынесенное в библиотеку действие в
/// «Командах» может не появиться вовсе.
///
/// СХЕМА ТА ЖЕ, ЧТО У ONE SEC: одно действие в автоматизации «когда открывается
/// приложение», соцсеть выбирается прямо в нём, возврат делает само приложение
/// по адресу соцсети. Возврат автоматизацию заново не поднимает: триггер
/// «когда открывается приложение» срабатывает на открытие человеком, а не на
/// программное — потому у one sec и нет зацикливания.
///
/// `openAppWhenRun` здесь единственный поддерживаемый способ поднять приложение.
/// Условного открытия в App Intents нет — это подтверждено DTS, — а
/// `ForegroundContinuableIntent` спрашивает у человека подтверждение и в
/// автоматизации дал бы диалог на каждую паузу. Попытка перейти на него
/// откачена.
struct ShowPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Verse pause"
    static let description = IntentDescription(
        "Shows the verse of the day over the app you just opened."
    )
    static let openAppWhenRun = true

    /// Куда вернуть человека по кнопке «Продолжить».
    ///
    /// Обязательный, и это принципиально. Пока он был необязательным и не
    /// входил в сводку, «Команды» прятали его под «Показать больше» — в плитке
    /// действия стояло одно название, поле никто не находил, и «Продолжить»
    /// вело в никуда. У one sec то же поле показано синим прямо в плитке с
    /// пометкой «must be selected»: без него автоматизация не запускается.
    @Parameter(title: "App")
    var app: PausedApp

    /// Сводка — это то, что человек видит в плитке действия. Приложение в ней
    /// стоит прямо в предложении, а не под сгибом.
    static var parameterSummary: some ParameterSummary {
        Summary("Verse pause before \(\.$app)")
    }

    /// Возвращается немедленно.
    ///
    /// Ждать здесь человека нельзя: «Команды» убивают действие, не уложившееся
    /// в отведённое время, и автоматизация падает с ошибкой. Разговор идёт уже
    /// внутри приложения, которое к этому моменту открыто.
    @MainActor
    func perform() async throws -> some IntentResult {
        PauseSession.shared.begin(returnTo: app.url)
        return .result()
    }
}

/// Готовая фраза для Siri и плитка в медиатеке «Команд».
///
/// Обращение к провайдеру нужно и в точке входа: больше на `DeepamShortcuts`
/// ссылок нет, метаданные типа выбрасываются при линковке, и рантайм App
/// Intents потом его не находит.
struct DeepamShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowPauseIntent(),
            phrases: ["Verse pause in \(.applicationName)",
                      "\(.applicationName) pause"],
            shortTitle: "Verse pause",
            systemImageName: "hand.raised"
        )
    }
}
