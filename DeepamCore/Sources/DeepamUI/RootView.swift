import DeepamCore
import StoreKit
import SwiftUI
#if canImport(WidgetKit) && !os(macOS)
import WidgetKit
#endif

/// Корневой экран: онбординг до первого запуска, дальше три вкладки.
public struct RootView: View {
    @State private var settings: AppSettings
    private let entitlements: any EntitlementStore
    @State private var tab: Tab = .today
    @State private var corpus: Corpus?
    @State private var loadFailed = false
    /// Пауза перед лентой. Её открывает не человек, а действие из «Команд»,
    /// поэтому состояние общее на процесс, а не своё у экрана.
    @State private var pause = PauseSession.shared
    /// Обучающий тур. Создаётся здесь, потому что ведёт вкладки.
    @State private var coach: Coach
    /// Лист поверх всего: «подписка закончилась» или пейволл, открытый тапом
    /// по закрытому StandBy. Один на двоих, чтобы второй мог сменить первый.
    @State private var proSheet: ProSheet?
    /// Сколько виджетов стоит — по последней переписи. `nil`, пока перепись не
    /// ответила: по незнанию нельзя ни звать «вернись», ни снимать отметки.
    @State private var widgetCount: Int?
    /// Что стоит по последней переписи — для напоминания про вторую поверхность.
    @State private var widgetSlots: [WidgetCensus.Slot] = []
    /// Тап по уведомлению с поверхностью — открыть её инструкцию.
    @State private var route = NotificationRoute.shared
    /// Отложенная просьба об оценке. Снимается, если человек ушёл с экрана
    /// раньше, чем она сработала.
    @State private var reviewTask: Task<Void, Never>?
    /// «Что нового» после обновления — см. `WhatsNew`.
    @State private var showsWhatsNew = false
    @Environment(\.l10n) private var l10n
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    public init(settings: AppSettings = AppSettings(),
                entitlements: any EntitlementStore = StubEntitlements()) {
        _settings = State(initialValue: settings)
        self.entitlements = entitlements
        _coach = State(initialValue: Coach(settings: settings))
    }

    public var body: some View {
        Group {
            if !settings.hasSeenOnboarding {
                // Корпус передаётся внутрь: первый экран онбординга показывает
                // настоящий стих на сегодня, а экран тем — сколько стихов
                // нашлось под выбранные. Обещать «нашли N» и не иметь N было
                // бы хуже, чем не обещать.
                OnboardingFlow(settings: settings, entitlements: entitlements,
                               card: dailyCard, corpus: corpus) {
                    settings.hasSeenOnboarding = true
                }
            } else if let corpus {
                tabs(corpus)
                    // Тур начинается по появлению вкладок, а не по концу
                    // онбординга. Иначе его никогда не увидит тот, кто прошёл
                    // онбординг на прежней сборке, где тура ещё не было, — а это
                    // все, кто уже держит приложение на телефоне.
                    //
                    // «Что нового» — после тура и не поверх него: идёт тур —
                    // экран подождёт следующего открытия.
                    .task {
                        coach.startIfNeeded()
                        if WhatsNew.isDue(settings), !coach.isRunning, proSheet == nil {
                            showsWhatsNew = true
                        }
                    }
                    .fullCover(isPresented: $showsWhatsNew, onDismiss: markWhatsNewSeen) {
                        WhatsNewFlow(settings: settings, entitlements: entitlements,
                                     card: dailyCard) { showsWhatsNew = false }
                            .themed(appTheme)
                            .localized(settings.language ?? .detect())
                    }
            } else if loadFailed {
                failure
            } else {
                ProgressView().tint(appTheme.accent)
            }
        }
        .task(id: settings.language) { await load() }
        // Язык интерфейса следует за выбором перевода: иначе выходит разнобой —
        // стих по-испански, а кнопки по-русски.
        .localized(settings.language ?? .detect())
        // Набор и шрифт из «Вида» красят всё приложение, а не только карточку.
        .themed(appTheme)
        // Смена шрифта перекраивает разметку целиком: у начертаний разная
        // ширина, и строки перебиваются заново. Без перехода это выглядит
        // рывком, будто экран моргнул. Здесь, а не на экране «Вида», потому что
        // меняется и таб-бар, и всё остальное под ним.
        .animation(.easeInOut(duration: 0.22), value: settings.font(for: .app))
        .animation(.easeInOut(duration: 0.22), value: settings.style(for: .app))
        .animation(.easeInOut(duration: 0.22), value: settings.scene(for: .app))
        // Системные детали — индикаторы прокрутки, полоска шторки — идут от
        // светлоты набора: на «Пергаменте» тёмная схема оставила бы их белыми
        // на светлом фоне.
        .preferredColorScheme(appTheme.isLight ? .light : .dark)
        // Пауза перекрывает всё, включая онбординг: соцсеть могли открыть в
        // любой момент, и стих должен встретить раньше ленты.
        .fullCover(isPresented: Binding(
            get: { pause.isShowing },
            set: { if !$0 { pause.finish() } }
        )) {
            if let card = dailyCard {
                PauseScreen(card: card, showsOriginal: settings.showsOriginal,
                            canReturn: pause.returnURL != nil) {
                    // «Продолжить» возвращает в соцсеть само приложение.
                    // Системное действие «Открыть приложение» для этого не
                    // годится: до него дело не доходит — «Команды» успевают
                    // убить наше действие по таймауту.
                    if let back = pause.finish() { openURL(back) }
                }
                .themed(appTheme)
                .localized(settings.language ?? .detect())
            }
        }
        // Свернул приложение, не нажав «Продолжить», — пауза всё равно
        // засчитывается: стих человек увидел. Без этого окно тишины не
        // записывалось, и следующее открытие соцсети снова поднимало паузу —
        // ровно то зацикливание, на которое напоролись.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, pause.isShowing { pause.finish() }
            if phase == .active { bounceIfNeeded() }
        }
        // Адрес для отскока может появиться и до того, как сцена стала активной,
        // и после: порядок между запуском действия и показом сцены не обещан.
        // Поэтому проверяем в обоих местах, а открываем только при активной.
        .onChange(of: pause.bounceURL) { _, _ in bounceIfNeeded() }
        // Виджеты ставят и убирают вне приложения, поэтому сверяемся при каждом
        // выходе на передний план, включая первый. Там же считаются дни
        // открытий — для просьбы об оценке.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                settings.review.recordOpen(day: VerseEngine.dayIndex(for: .now))
                takeWidgetCensus()
            } else {
                reviewTask?.cancel()
            }
        }
        // Очередь уведомлений зависит от всего, что меняет их текст или время:
        // включения, времени, тем (они меняют стих дня) и языка корпуса.
        .onChange(of: settings.dailyVerseEnabled) { _, _ in rescheduleReminders() }
        .onChange(of: settings.dailyVerseMinutes) { _, _ in rescheduleReminders() }
        .onChange(of: settings.themes) { _, _ in rescheduleReminders() }
        .onChange(of: corpus?.lang) { _, _ in rescheduleReminders() }
        // Свойства человека — для отчётов и для таргета кампаний Firebase
        // Messaging: на каком языке писать и звать ли включить стих дня.
        .onChange(of: settings.language, initial: true) { _, _ in reportTraits() }
        .onChange(of: settings.dailyVerseEnabled, initial: true) { _, _ in reportTraits() }
        .onChange(of: entitlements.isSubscribed, initial: true) { _, _ in reportTraits() }
        .onChange(of: settings.promoOptIn, initial: true) { _, _ in reportTraits() }
        // Рассылка с ключами `tab`, `paywall` или `offering` — см. `PushAction`.
        // Пока онбординг не пройден, вести некуда: вкладок ещё нет, а
        // пейволл и так будет в его конце.
        .onChange(of: route.tab, initial: true) { _, next in
            guard let next else { return }
            route.tab = nil
            if settings.hasSeenOnboarding { tab = next }
        }
        .onChange(of: route.paywall, initial: true) { _, paywall in
            guard let paywall else { return }
            route.paywall = nil
            if settings.hasSeenOnboarding { proSheet = .paywall(.push, offering: paywall.offering) }
        }
        .sheet(item: Binding(get: { route.surface }, set: { route.surface = $0 })) { surface in
            InstructionSheet(surface: surface) { settings.markInstalled(surface) }
                .themed(appTheme)
                .localized(settings.language ?? .detect())
        }
        // Каждый ответ RevenueCat сверяется с оформлением: подписка могла
        // кончиться, пока приложение было закрыто.
        .onChange(of: entitlements.proStatus, initial: true) { _, status in
            applyProStatus(status)
        }
        // Тап по закрытому StandBy приходит сюда адресом `deepam://pro`.
        // Регистрировать схему не нужно: адрес из виджета система отдаёт
        // своему приложению напрямую.
        .onOpenURL { url in
            if url.scheme == "deepam", url.host == "pro" { proSheet = .paywall(.standBy) }
        }
        .sheet(item: $proSheet) { sheet in
            Group {
                switch sheet {
                case .expired:
                    ProExpiredSheet { proSheet = .paywall(.expired) }
                case let .paywall(source, offering):
                    PaywallSheet(settings: settings, entitlements: entitlements, source: source,
                                 pick: source == .standBy ? PaywallPick(.standBy, name: "StandBy") : nil,
                                 offering: offering)
                case .cancelReason:
                    CancelReasonSheet()
                }
            }
            // Лист висит снаружи `.themed` и `.localized`, поэтому получает их
            // сам — как и пауза выше.
            .themed(appTheme)
            .localized(settings.language ?? .detect())
        }
    }

    /// Сверяет оформление с подпиской.
    ///
    /// Снимает платное только при известном конце. `nil` — ответа ещё не было,
    /// например нет сети на запуске, — сюда не доходит, и подписчик в метро
    /// свой фон не теряет.
    private func applyProStatus(_ status: ProStatus?) {
        guard let status else { return }
        settings.updateProStatus(status)
        // Триал отменён, но ещё идёт — спросить почему, один раз. Отменяют
        // обычно в настройках iPhone, и других шансов узнать причину нет.
        if status.isCancelledTrial, !settings.cancelReasonAsked, proSheet == nil {
            settings.cancelReasonAsked = true
            proSheet = .cancelReason
        }
        guard !status.grants(at: .now) else { return }
        let changed = settings.dropPremiumAppearance()
        // Иконку меняет только система, и только из приложения. Ставится та,
        // что осталась в настройках после отката: платная там уже сменилась на
        // основную, а бесплатный «Голубь» остаётся. Раньше здесь стояла
        // основная для всех — и «Голубь» слетал бы при каждом ответе
        // RevenueCat. Если иконка и так та же, вызов ничего не делает.
        AppIconSwitcher.apply(AppIcon(rawValue: settings.appIcon) ?? .default)
        if changed, proSheet == nil { proSheet = .expired }
    }

    private enum ProSheet: Identifiable {
        case expired
        case cancelReason
        /// Источник едет вместе с листом: пейволл сюда приводят и StandBy, и
        /// лист «подписка закончилась», и рассылки, и в отчётах это разные
        /// замки. Предложение RevenueCat — у рассылок с акцией.
        case paywall(PaywallSource, offering: String? = nil)

        var id: String {
            switch self {
            case .expired: "expired"
            case .cancelReason: "cancelReason"
            case let .paywall(source, offering): "paywall.\(source.rawValue).\(offering ?? "")"
            }
        }
    }

    /// Перепись виджетов: аналитика, отметки в «Местах» и очередь уведомлений.
    ///
    /// Отметки экрана блокировки и рабочего стола ставятся и снимаются по
    /// факту: убрали виджет — на «Сегодня» снова кнопка «Поставить». Виджеты
    /// есть — «стих пропал с экрана?» отодвигается; нет — снимается, потому
    /// что человек сейчас здесь и кнопку увидит сам.
    private func takeWidgetCensus() {
        Task {
            guard let slots = await Self.currentWidgets() else { return }
            for event in WidgetCensus().update(slots) { EventLog.log(event) }
            EventLog.setWidgetCount(slots.count)
            settings.syncWidgetSurfaces(slots)
            widgetCount = slots.count
            widgetSlots = slots
            // Впервые одна поверхность — назавтра предложить вторую. Дата
            // ставится один раз и дальше не сдвигается.
            if settings.secondSurfaceDue == nil, ReminderPlan.SecondSurface.missing(in: slots) != nil {
                settings.secondSurfaceDue = .now.addingTimeInterval(86_400)
            }
            if slots.isEmpty {
                Reminders.cancelWidgetGone()
            } else {
                Reminders.postponeWidgetGone(l10n: L10n(settings.language ?? .detect()))
            }
            rescheduleReminders()
            askForReviewIfDue(widgetCount: slots.count)
        }
    }

    /// Просьба об оценке — тем, кто прижился (см. `ReviewPrompt`).
    ///
    /// Не поверх того, что человек сейчас делает: онбординга, паузы перед
    /// лентой, тура и листов. Две секунды ожидания — чтобы окно не встречало
    /// на пороге и чтобы успели открыться листы по ответу RevenueCat; после
    /// ожидания всё проверяется заново. Ушёл с экрана — просьба снимается:
    /// иначе её списало бы открытие, после которого автоматизация паузы сразу
    /// возвращает в соцсеть.
    private func askForReviewIfDue(widgetCount: Int) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard reviewTask == nil,
              settings.review.isDue(widgetCount: widgetCount, version: version, now: .now) else { return }
        reviewTask = Task {
            defer { reviewTask = nil }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, settings.hasSeenOnboarding, !pause.isShowing,
                  !coach.isRunning, !showsWhatsNew, proSheet == nil, route.surface == nil else { return }
            settings.review.markAsked(version: version, now: .now)
            EventLog.log(.reviewPrompt(source: "auto"))
            requestReview()
        }
    }

    /// Что стоит на экранах. `nil` — система не ответила или это не iPhone.
    ///
    /// Ответ приходит не на главном потоке, поэтому из обратного вызова
    /// выносятся только готовые значения.
    private static func currentWidgets() async -> [WidgetCensus.Slot]? {
        #if canImport(WidgetKit) && !os(macOS)
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                guard case let .success(widgets) = result else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: widgets.map {
                    WidgetCensus.Slot(kind: $0.kind, family: $0.family.description)
                })
            }
        }
        #else
        nil
        #endif
    }

    /// Напоминание про вторую поверхность — пока она всё ещё одна.
    private var secondSurface: ReminderPlan.SecondSurface? {
        guard let due = settings.secondSurfaceDue,
              let missing = ReminderPlan.SecondSurface.missing(in: widgetSlots) else { return nil }
        return ReminderPlan.SecondSurface(due: due, missing: missing)
    }

    private func reportTraits() {
        EventLog.setUserProperty((settings.language ?? .detect()).rawValue, forName: "app_language")
        EventLog.setUserProperty(settings.dailyVerseEnabled ? "on" : "off", forName: "daily_verse")
        EventLog.setUserProperty(entitlements.isSubscribed ? "yes" : "no", forName: "pro")
        // Рекламные рассылки (акции, скидки) — только по аудитории `yes`.
        EventLog.setUserProperty(settings.promoOptIn ? "yes" : "no", forName: "promo_optin")
    }

    /// Закрыли «Что нового» — крестиком, кнопкой или смахнув. Второй раз за
    /// эту версию он не покажется.
    private func markWhatsNewSeen() {
        settings.whatsNewSeen = WhatsNew.version
    }

    /// Пересобирает очередь уведомлений: стих дня на месяц вперёд и возврат
    /// тем, у кого стих нигде не появляется сам.
    private func rescheduleReminders() {
        guard let corpus else { return }
        Reminders.replace(with: ReminderPlan.make(
            now: .now,
            dailyVerseEnabled: settings.dailyVerseEnabled,
            dailyVerseMinutes: settings.dailyVerseMinutes,
            widgetCount: widgetCount,
            secondSurface: secondSurface,
            pool: corpus.cards(themes: settings.themes),
            l10n: L10n(settings.language ?? .detect())
        ))
    }

    /// Пауза только что пройдена, а автоматизация подняла приложение снова —
    /// отправить человека обратно в соцсеть, ничего не показывая.
    private func bounceIfNeeded() {
        guard scenePhase == .active, let url = pause.consumeBounce() else { return }
        openURL(url)
    }

    /// Стих дня. Им кормится и пауза, и предпросмотр на «Виде»: человек
    /// настраивает вид того, что реально сейчас видит, а не первой попавшейся
    /// карточки корпуса.
    ///
    /// Если корпус ещё не прочитан, паузу показывать нечем: действие из
    /// «Команд» будит приложение из выключенного состояния, и данные приезжают
    /// не мгновенно. Тогда экран пропускается, а не висит пустым.
    private var dailyCard: Card? {
        guard let corpus else { return nil }
        let pool = corpus.cards(themes: settings.themes)
        guard !pool.isEmpty else { return nil }
        let engine = VerseEngine(poolCount: pool.count)
        return pool[engine.index(offset: 0, on: VerseEngine.dayIndex(for: .now))]
    }

    /// Оформление всего приложения. Считается здесь, а не читается из
    /// окружения: `.themed()` задаёт его детям, а сам `RootView` видел бы
    /// значение по умолчанию — «Лаванду» независимо от выбора.
    private var appTheme: AppTheme {
        AppTheme(style: settings.style(for: .app), font: settings.font(for: .app),
                 scene: settings.scene(for: .app))
    }

    /// Каркас из макета: фон, колонка содержимого и под ней слот таб-бара.
    /// Таб-бар не накрывает содержимое, а занимает свою полосу — в макете это
    /// отдельный узел «Tab Bar Slot» высотой 92 точки.
    private func tabs(_ corpus: Corpus) -> some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case .today:
                        // «Места» и «Вид» ставят колонку сами, внутри своей
                        // прокрутки: снаружи она сузила бы и саму прокрутку, и
                        // по полям широкого экрана листать бы не получалось.
                        TodayScreen(corpus: corpus, settings: settings,
                                    entitlements: entitlements, coach: coach)
                            .readableColumn()
                    case .places:
                        PlacesScreen(settings: settings, entitlements: entitlements, coach: coach)
                    case .look:
                        LookScreen(settings: settings, entitlements: entitlements,
                                   sample: dailyCard, coach: coach)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Таб-бар свой, а не системный, поэтому вертикальным на внешнем
                // экране iPhone Duo не становится: туда система уводит только
                // `TabView`. Остаётся внизу, в безопасной области, — работает
                // так же, как на любом iPhone.
                TabBarSlot(selection: $tab)
                    .readableColumn()
            }
        }
        // Тур сам переводит вкладку: подсказка не имеет смысла, если указывает
        // на то, чего сейчас на экране нет.
        .onChange(of: coach.step) { _, step in
            guard let step else { return }
            withAnimation(.snappy(duration: 0.25)) { tab = Tab(coachTab: step.tab) }
        }
        .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            if let step = coach.step {
                CoachOverlay(coach: coach, step: step, anchors: anchors)
            }
        }
    }

    /// Фон выводится из набора: пятно света на своём месте у каждой вкладки,
    /// но цвета берутся из темы — иначе выбор «Пергамента» покрасил бы
    /// карточки, а фон остался бы тёмно-фиолетовым.
    @ViewBuilder
    private var background: some View {
        switch tab {
        case .today: ScreenBackground(glow: .bottomLeft)
        case .places: ScreenBackground(glow: .topLeft)
        case .look: ScreenBackground(glow: nil)
        }
    }

    /// Корпус лежит в бандле, поэтому «не загрузился» означает испорченную
    /// сборку, а не сеть. Показываем это прямо, без предложения повторить.
    private var failure: some View {
        VStack(spacing: 10) {
            Text(l10n[.corpusFailedTitle])
                .font(appTheme.display(20))
                .foregroundStyle(appTheme.text)
            Text(l10n[.corpusFailedHint])
                .font(appTheme.ui(13))
                .foregroundStyle(appTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScreenBackground(glow: .bottomLeft))
    }

    private func load() async {
        let locale = settings.language ?? .detect()
        do {
            corpus = try Corpus.load(locale)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}
