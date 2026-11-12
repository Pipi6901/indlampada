import DeepamCore
import SwiftUI

/// Онбординг v3 (1.0.2) — блок «Онбординг v3» в файле дизайна.
///
/// Сначала ценность без единого вопроса: настоящий стих на сегодня. Потом
/// ровно один вопрос — «Что тебе сейчас нужнее?», — и ответ ведёт дальше:
/// экран своей ветки (темы, время стиха, «сколько уходит на ленту», вид стиха)
/// и пейволл своей ветки в конце.
///
/// Между вопросом и пейволлом — два «ага» прямо в приложении, без выхода из
/// него: первый стих приходит настоящим уведомлением, а иконка меняется сразу,
/// по тапу. Единственное, ради чего приходится выйти, — виджет на экран
/// блокировки; вернулся с ним — перепись это видит, и шаг сменяется
/// «Готово». Пауза перед лентой и время стиха (вне ветки «Каждый день»)
/// из онбординга ушли в «Места»: шесть просьб подряд теряли людей.
///
/// ATT стоит после «почему», а не вторым экраном: после «ага» мотивация выше,
/// а ответ всё равно приходит до триала — оптимизации Meta по StartTrial
/// этого достаточно.
///
/// Экрана выбора языка здесь нет намеренно: язык берётся из системной локали, а
/// сменить его можно на первом экране. Отдельный шаг «выбери язык» терял
/// людей на месте, где им ещё нечего выбирать.
///
/// Обращение на «ты» — из макета, оно держится на всех экранах.

// MARK: - Оформление ряда

/// Палитра и шрифты онбординга заданы здесь, а не берутся из «Вида».
///
/// Причина простая: выбирать оформление человек будет позже и за деньги, а
/// первые экраны — брендовые, у каждого свой градиент и антиква в заголовке.
/// Взять пользовательскую тему значило бы, что приложение открывается
/// системным списком на сером фоне.
///
/// Newsreader и Outfit из макета заменены на Literata и Onest: ни один из
/// исходных не содержит кириллицы, и на русском система молча подставила бы
/// своё. Замены подобраны по рисунку и уже лежат в пакете.
enum OB {
    static let ink = Color(hex: 0x1B0B0F)
    static let brass = Color(hex: 0xEBA654)
    static let text = Color(hex: 0xF4E8DC)
    static let textMuted = Color(hex: 0xD3BBAC)
    static let textFaint = Color(hex: 0xA08A7E)
    static let line = Color(hex: 0x5A2A31)
    static let raised = Color(hex: 0x3A1A21)
    static let violet = Color(hex: 0xF08A35)
    static let violetDeep = Color(hex: 0x8E1F2A)
    static let onBrass = Color(hex: 0x2A0F10)

    static func display(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        Fonts.font(.literata, size: size, weight: weight)
    }

    static func ui(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        Fonts.font(.onest, size: size, weight: weight)
    }

    /// Межстрочный интервал под высоту строки из макета.
    static func spacing(_ size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        Fonts.lineSpacing(.literata, size: size, lineHeight: lineHeight)
    }
}

/// Фон экрана: вертикальный градиент и мягкое пятно света.
///
/// Пятно не декоративное — оно ведёт взгляд туда, где на экране главное, и на
/// каждом шаге стоит в своём месте.
struct OBBackground: View {
    struct Glow {
        let color: Color
        let size: CGFloat
        /// Левый верхний угол пятна, как в макете.
        let x: CGFloat
        let y: CGFloat
    }

    let stops: [Gradient.Stop]
    var glow: Glow? = nil

    var body: some View {
        // Пятно — накладка на градиент, а НЕ сосед по стопке. В стопке оно
        // задавало бы размер: круг здесь 420–480 точек, а экран 393, и стопка
        // растягивалась по кругу. Дальше по цепочке в этот контейнер ложилось
        // всё содержимое экрана — оно уезжало левее экрана и обрезалось с
        // обеих сторон. Накладка на размер родителя не влияет никогда.
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .topLeading) {
                if let glow {
                    Circle()
                        .fill(RadialGradient(colors: [glow.color, glow.color.opacity(0)],
                                             center: .center,
                                             startRadius: 0,
                                             endRadius: glow.size / 2))
                        .frame(width: glow.size, height: glow.size)
                        .offset(x: glow.x, y: glow.y)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
    }
}

/// Тёмный набор экранов онбординга и «Что нового»: один и тот же градиент,
/// разное пятно.
let obDeep: [Gradient.Stop] = [
    .init(color: Color(hex: 0x3E141C), location: 0),
    .init(color: Color(hex: 0x240D12), location: 0.6),
    .init(color: OB.ink, location: 1),
]

/// Главная кнопка ряда — латунная, во всю ширину.
struct OBButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OB.ui(17, weight: 600))
            .spaced(0.1)
            .foregroundStyle(OB.onBrass)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(OB.brass))
            .shadow(color: Color(hex: 0xD3BBAC).opacity(0.18), radius: 14, y: 8)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Полоса прогресса: пять шагов, текущий длиннее.
///
/// Считается с единицы и показывается на пяти шагах от вопроса до виджета.
/// На первом, «Готово», «почему» и ATT её нет: там ничего не просят, и полоса
/// обещала бы работу, которой не будет.
private struct OBProgress: View {
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? OB.brass : OB.line)
                    .frame(width: index == step ? 26 : 14, height: 4)
            }
        }
    }
}

/// Вторая кнопка ряда — ссылка под главной: «Поставлю позже», «Решу позже».
struct OBLink: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OB.ui(14, weight: 500))
            .foregroundStyle(OB.textMuted)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Надпись, заголовок и подзаголовок шага — одинаковые на всех экранах ряда.
struct OBHeading: View {
    var eyebrow: String? = nil
    let title: String
    var sub: String? = nil
    /// Подзаголовок курсивом антиквы — у вопросов, где он продолжает заголовок,
    /// а не объясняет его.
    var italicSub = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow {
                Text(eyebrow)
                    .font(OB.ui(10, weight: 600))
                    .spaced(2)
                    .foregroundStyle(OB.brass)
            }

            Text(title)
                .font(OB.display(34))
                .spaced(-0.7)
                .lineSpacing(OB.spacing(34, lineHeight: 1.1))
                .foregroundStyle(OB.text)
                .fixedSize(horizontal: false, vertical: true)

            if let sub {
                Text(sub)
                    .font(italicSub ? OB.display(19).italic() : OB.ui(14))
                    .lineSpacing(italicSub ? 3 : 5)
                    .foregroundStyle(OB.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Поток

/// Платное, что человек выбрал по дороге: иконка на шаге иконки, набор или
/// картинка на ветке «Красиво».
///
/// Сразу не включается — без подписки нечем. Пейволл ветки «Красиво» показывает
/// это плашками «Твой выбор», а после покупки выбранное встаёт на место само:
/// человек купил ровно то, что видел.
struct OnboardingPicks: Equatable {
    var icon: AppIcon?
    var style: VerseStyle?
    var scene: VerseScene?

    /// Где включается вид с ветки «Красиво»: приложение и виджеты. На экране
    /// блокировки цвет задаёт система.
    static let lookAreas: [AppearanceArea] = [.app, .widgets]

    /// Плашки для пейволла. Иконка первой — так в макете.
    func paywall(_ l10n: L10n) -> [PaywallPick] {
        var picks: [PaywallPick] = []
        if let icon { picks.append(PaywallPick(.icons, name: l10n[icon.titleKey])) }
        if let scene { picks.append(PaywallPick(.pictures, name: l10n[scene.titleKey])) }
        if let style { picks.append(PaywallPick(.sets, name: l10n[style.titleKey])) }
        return picks
    }

    @MainActor
    func apply(to settings: AppSettings) {
        if let icon {
            settings.appIcon = icon.rawValue
            AppIconSwitcher.apply(icon)
        }
        for area in Self.lookAreas {
            if let style { settings.setStyle(style, for: area) }
            if let scene { settings.setScene(scene, for: area) }
        }
    }
}

public struct OnboardingFlow: View {
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    /// Стих дня — им живёт первый экран, первое уведомление и предпросмотры.
    /// `nil`, пока корпус не прочитан: экран тогда обходится без стиха, а не
    /// ждёт пустым.
    let card: Card?
    let corpus: Corpus?
    let onFinish: () -> Void

    /// Шаги по порядку. Номер уходит в аналитику вместе с именем; ветку
    /// отчёты различают по имени (`themes`, `time`, `feed`, `look`).
    enum Step: Int {
        case verse, goal, branch, firstVerse, icon, widget, done, why, tracking
    }

    @State private var step = Step.verse
    @State private var picks = OnboardingPicks()
    @State private var showsPaywall = false
    @State private var showsLanguage = false
    @State private var welcomeOffer: WelcomeOffer?
    @Environment(\.paywallStore) private var store
    @Environment(\.l10n) private var l10n

    public init(settings: AppSettings,
                entitlements: any EntitlementStore,
                card: Card? = nil,
                corpus: Corpus? = nil,
                onFinish: @escaping () -> Void) {
        self.settings = settings
        self.entitlements = entitlements
        self.card = card
        self.corpus = corpus
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            switch step {
            case .verse: VersePage(card: card,
                                   language: settings.language ?? .detect(),
                                   showsOriginal: settings.showsOriginal,
                                   onLanguage: { showsLanguage = true },
                                   onNext: { step = .goal })
            case .goal: GoalPage(settings: settings) { step = .branch }
            case .branch: branch
            case .firstVerse: FirstVersePage(settings: settings, card: card) { step = .icon }
            case .icon: OBIconPage(settings: settings, entitlements: entitlements,
                                   pick: $picks.icon) { step = .widget }
            case .widget: OBWidgetPage(settings: settings, card: card,
                                       onInstalled: { step = .done },
                                       onLater: { step = .why })
            case .done: DonePage { step = .why }
            case .why: WhyPage(onNext: afterWhy)
            case .tracking: OBTrackingPage { showsPaywall = true }
            }
        }
        .animation(.snappy(duration: 0.25), value: step)
        // Каждый шаг — отдельное событие: по ним видно, где люди сходят с
        // онбординга, не доходя до пейволла.
        .onChange(of: step, initial: true) { previous, step in
            EventLog.log(.onboardingStep(index: step.rawValue, name: stepName(step)))
            // Ответы уходят, когда с экрана ушли вперёд: так в отчёт попадает
            // окончательный выбор, а не каждое касание.
            if previous == .goal, let goal = settings.goal { logAnswers("goal", [goal.rawValue]) }
            if previous == .branch, settings.goal == .comfort { logAnswers("theme", Array(settings.themes)) }
        }
        .sheet(isPresented: $showsLanguage) { LanguageSheet(settings: settings) }
        // `hasSeenOnboarding` ставит уже `onFinish`, когда пейволл закрыли.
        // Поставить его здесь значило бы снести этот экран вместе с накрытием
        // раньше, чем пейволл успеет появиться.
        .fullCover(isPresented: $showsPaywall, onDismiss: paywallClosed) {
            PaywallScreen(settings: settings, entitlements: entitlements, source: .onboarding,
                          onboardingPicks: picks.paywall(l10n))
        }
        .fullCover(isPresented: Binding(get: { welcomeOffer != nil },
                                        set: { if !$0 { welcomeOffer = nil } }),
                   onDismiss: complete) {
            if let welcomeOffer {
                WelcomeOfferScreen(entitlements: entitlements, offer: welcomeOffer)
            }
        }
    }

    /// Экран ветки. Ответа нет — быть не может: «Дальше» на вопросе без него
    /// не нажимается. Но если всё же нет, ведём самой короткой — со временем.
    @ViewBuilder
    private var branch: some View {
        switch settings.goal ?? .daily {
        case .comfort: OBThemesPage(settings: settings, corpus: corpus) { step = .firstVerse }
        case .daily: OBTimePage(settings: settings, card: card) { step = .firstVerse }
        case .feed: OBFeedPage { step = .firstVerse }
        case .beauty: OBLookPage(settings: settings, entitlements: entitlements, card: card,
                                 picks: $picks) { step = .firstVerse }
        }
    }

    /// Пейволл закрыт. Не купили и скидка положена — второй шанс, один раз;
    /// иначе онбординг закончен.
    private func paywallClosed() {
        if !entitlements.isSubscribed, !settings.welcomeOfferShown, let offer = store?.welcomeOffer {
            settings.welcomeOfferShown = true
            welcomeOffer = offer
        } else {
            complete()
        }
    }

    private func complete() {
        // Купили — на шагах иконки и вида выбранное включается само.
        if entitlements.isSubscribed { picks.apply(to: settings) }
        // Новинки 1.0.2 онбординг показал сам — «Что нового» им ни к чему.
        settings.whatsNewSeen = WhatsNew.version
        EventLog.log(.onboardingComplete)
        onFinish()
    }

    /// Каждый вариант — отдельным событием. Ничего не выбрали — тоже ответ.
    ///
    /// В Deepam ответы онбординга (цель, состояния) в аналитику НЕ уходят: по
    /// ним можно судить о вере человека, а это особая категория данных
    /// (GDPR, ст. 9). Функция оставлена пустой, чтобы не трогать вызовы; в
    /// политике конфиденциальности сказано, что ответы остаются на телефоне.
    private func logAnswers(_ question: String, _ answers: [String]) {}

    /// Имя шага для отчётов. Номера сдвигались уже дважды — в 1.0.2 с шагом
    /// ATT и с онбордингом v3, — поэтому отчёты строятся по имени.
    private func stepName(_ step: Step) -> String {
        switch step {
        case .verse: "verse"
        case .goal: "goal"
        case .branch:
            switch settings.goal ?? .daily {
            case .comfort: "themes"
            case .daily: "time"
            case .feed: "feed"
            case .beauty: "look"
            }
        case .firstVerse: "first_verse"
        case .icon: "icon"
        case .widget: "widget"
        case .done: "done"
        case .why: "why"
        case .tracking: "tracking"
        }
    }

    /// Шаг ATT есть, только когда спрашивать есть что: система ещё не знает
    /// ответа и приложение поставило, кому его передать.
    private func afterWhy() {
        if AdTracking.prompt == nil {
            showsPaywall = true
        } else {
            step = .tracking
        }
    }
}

// MARK: - 01 Стих на сегодня

/// Ценность до вопросов: настоящий стих на сегодня, ещё до того как у человека
/// что-нибудь спросили. В v3 экран почищен: ни подводки, ни даты, язык —
/// просто строкой, и стих мельче, чтобы лампа над ним дышала.
private struct VersePage: View {
    @Environment(\.l10n) private var l10n
    let card: Card?
    let language: AppLocale
    let showsOriginal: Bool
    let onLanguage: () -> Void
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            OBBackground(stops: [
                .init(color: Color(hex: 0x421720), location: 0),
                .init(color: Color(hex: 0x28101A), location: 0.5),
                .init(color: OB.ink, location: 1),
            ])

            // Светильник чуть опущен (раньше lift был 130, цепочка уходила за верхний
            // край), а стих прижат к кнопке: оригинал над переводом занимает втрое
            // больше места, чем один перевод, и по центру экрана он лёг бы прямо
            // на пламя. Растворение внизу картинки прячет её нижний край.
            OBPoster(lift: 40) { HeroLantern() }

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 12)
                verse
                Color.clear.frame(height: 20)
                bottom
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            // Шаги онбординга свёрстаны в высоту макета без прокрутки. На
            // внешнем экране iPhone Duo и на внутреннем лёжа они не влезают —
            // см. `ScreenLayout`.
            .readableColumn()
            .fitOrScroll()
        }
    }

    private var header: some View {
        HStack {
            Text("D E E P A M")
                .font(OB.ui(12, weight: 600))
                .kerning(3.4)
                .foregroundStyle(OB.brass)
            Spacer()
            Button(action: onLanguage) {
                HStack(spacing: 6) {
                    Text(language.nativeName)
                        .font(OB.ui(12.5, weight: 500))
                        .foregroundStyle(OB.textMuted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(OB.textFaint)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var verse: some View {
        if let card {
            VStack(alignment: .leading, spacing: 18) {
                Text(l10n[.obVerseEyebrow])
                    .font(OB.ui(10, weight: 600))
                    .spaced(2)
                    .foregroundStyle(OB.textFaint)

                // Кегль по длине стиха: пул неоднородный, от пяти слов до
                // абзаца. Мельче, чем на «Сегодня», — над текстом должен
                // дышать светильник.
                VerseText(parts: card.parts(locale: language, showsOriginal: showsOriginal),
                          scale: 0.9, lineHeight: 1.15, color: OB.text,
                          face: .literata, tracking: -0.7)

                // Подпись «— АН-НИСА 4:110» убрана с первого экрана по просьбе куратора: на
                // нём стих нужен как образец, а ссылка есть на «Сегодня» и в виджетах.
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottom: some View {
        VStack(spacing: 16) {
            Button(l10n[.obVerseCta], action: onNext)
                .buttonStyle(OBButton())

            Text(l10n[.obVerseTrust])
                .font(OB.ui(11))
                .spaced(0.2)
                .foregroundStyle(OB.textFaint)
        }
    }
}

/// Плакат на весь экран с растворением книзу: заставка первого слайда, лампа
/// на «Готово» и лампа с лентой на скидке после пейволла.
///
/// Картинка занимает весь экран, а не полосу сверху. Полоса давала видимый
/// шов: растворение доходило до чёрного ровно на её нижней кромке, а фон
/// экрана в этом месте был ещё не чёрным — на тёмном экране разница в шесть
/// единиц яркости читается как отрезанный край. Теперь растворение сходит на
/// нет к низу экрана, где фон и без того того же цвета, и стыка нет вовсе.
///
/// Сдвиг вниз опускает лампу к середине, как в макете v3. Открывшуюся сверху
/// полосу закрывает фон экрана, а верхний край картинки растворён — иначе там
/// был бы тот же шов.
struct OBPoster<Content: View>: View {
    var drop: CGFloat = 64
    /// Подъём всей картинки без изменения размера: открывшуюся снизу полосу
    /// закрывает фон экрана, а картинка к низу растворена в тот же цвет, так что
    /// шва нет. Нужен, когда под картинкой должно остаться место для текста.
    var lift: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
            ], startPoint: .top, endPoint: .bottom))
            .overlay(
                LinearGradient(stops: [
                    .init(color: OB.ink.opacity(0), location: 0),
                    .init(color: Color(hex: 0x1C0A0E).opacity(0.86), location: 0.46),
                    .init(color: OB.ink, location: 0.84),
                ], startPoint: .top, endPoint: .bottom)
            )
            .padding(.top, drop)
            .ignoresSafeArea()
            .offset(y: -lift)
            .allowsHitTesting(false)
    }
}

// MARK: - 02 Что нужнее

/// Один ответ из четырёх, и он меняет путь: экран ветки сразу после и пейволл
/// в конце. Мультивыбор из пяти «намерений» до 1.0.2 только копил ответы —
/// путь от них не менялся.
private struct GoalPage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let onNext: () -> Void

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.33),
                                     size: 420, x: 150, y: -160))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 1)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                OBHeading(title: l10n[.goalTitle], sub: l10n[.goalLead], italicSub: true)
                    .padding(.bottom, 24)

                VStack(spacing: 9) {
                    ForEach(OnboardingGoal.allCases) { row($0) }
                }
                .padding(.bottom, 24)

                Text(l10n[.goalHint])
                    .font(OB.ui(12))
                    .foregroundStyle(OB.textFaint)

                Spacer(minLength: 20)

                Button(l10n[.next], action: onNext)
                    .buttonStyle(OBButton())
                    .disabled(settings.goal == nil)
                    .opacity(settings.goal == nil ? 0.5 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }

    private func row(_ goal: OnboardingGoal) -> some View {
        let isOn = settings.goal == goal
        return Button { settings.goal = goal } label: {
            HStack(spacing: 14) {
                Image(goal.asset, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n[goal.titleKey])
                        .font(OB.ui(15.5, weight: 600))
                        .foregroundStyle(OB.text)
                    Text(l10n[goal.subKey])
                        .font(OB.ui(12.5))
                        .foregroundStyle(OB.textMuted)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isOn ? "checkmark.circle" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(isOn ? OB.text : Color(hex: 0x7C625A))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isOn ? OB.brass.opacity(0.08) : OB.raised))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isOn ? OB.brass : OB.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 03-У Темы (ветка «Утешение»)

private struct OBThemesPage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let corpus: Corpus?
    let onNext: () -> Void

    /// Темы берутся из корпуса, а не задаются списком: корпус — источник
    /// истины, и разъехаться им нельзя. В макете чипов одиннадцать, но это был
    /// эскиз; в собранном корпусе их шестнадцать.
    private var themes: [String] {
        corpus?.themes.sorted() ?? []
    }

    /// Сколько стихов под выбранное. Ничего не выбрано — весь корпус: так же
    /// считает и выдача.
    private var found: Int {
        corpus?.cards(themes: settings.themes).count ?? 0
    }

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violet.opacity(0.18),
                                     size: 460, x: -120, y: 380))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 2)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                OBHeading(title: l10n[.obThemesTitle], sub: l10n[.obThemesSub])
                    .padding(.bottom, 24)

                ScrollView {
                    FlowLayout(spacing: 10) {
                        ForEach(themes, id: \.self) { chip($0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 14) {
                    Text(l10n(.obThemesCounter, settings.themes.count, l10n.count(found, .versesUnit)))
                        .font(OB.ui(13))
                        .foregroundStyle(OB.textFaint)

                    Button(l10n[.next], action: onNext)
                        .buttonStyle(OBButton())
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            // Только колонка: у этого шага своя прокрутка списка тем, и
            // недостаток высоты она и так забирает на себя.
            .readableColumn()
        }
    }

    private func chip(_ name: String) -> some View {
        let isOn = settings.themes.contains(name)
        return Button {
            if isOn { settings.themes.remove(name) } else { settings.themes.insert(name) }
        } label: {
            Text(l10n.theme(name))
                .font(OB.ui(15, weight: isOn ? 600 : 500))
                .foregroundStyle(isOn ? OB.onBrass : OB.textMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Capsule().fill(isOn ? OB.brass : OB.raised))
                .overlay(Capsule().strokeBorder(isOn ? OB.brass : OB.line, lineWidth: 1))
                .shadow(color: isOn ? OB.brass.opacity(0.2) : .clear, radius: 10, y: 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 03-К Время (ветка «Каждый день»)

/// Время выбирается здесь, а разрешение спрашивается следующим шагом — там,
/// где первый стих приходит сразу. Системный вопрос «можно присылать?» без
/// времени спрашивал бы неизвестно о чём, а здесь, до «ага», звучал бы
/// просьбой.
private struct OBTimePage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let card: Card?
    let onNext: () -> Void

    @State private var time = ClockTime.date(minutes: AppSettings.defaultDailyVerseMinutes)

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 400, x: -60, y: 160))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 2)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                OBHeading(eyebrow: l10n[.obTimeEyebrow], title: l10n[.obTimeTitle], sub: l10n[.obTimeSub])

                Spacer(minLength: 16)

                OBBanner(card: card)

                DatePicker(l10n[.dailyVerseTime], selection: $time, displayedComponents: .hourAndMinute)
                    .wheelStyle()
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .clipped()
                    .padding(.top, 8)

                Spacer(minLength: 10)

                VStack(spacing: 16) {
                    Button(l10n(.dailyVerseOn, timeText)) {
                        settings.dailyVerseMinutes = ClockTime.minutes(from: time)
                        onNext()
                    }
                    .buttonStyle(OBButton())

                    Button(l10n[.obTimeLater], action: onNext)
                        .buttonStyle(OBLink())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
        .onAppear { time = ClockTime.date(minutes: settings.dailyVerseMinutes) }
    }

    private var timeText: String {
        ClockTime.text(minutes: ClockTime.minutes(from: time), locale: l10n.locale)
    }
}

/// Уведомление со стихом — так оно и будет выглядеть: настоящий стих на
/// сегодня.
struct OBBanner: View {
    @Environment(\.l10n) private var l10n
    let card: Card?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("icon-default", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Deepam")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(l10n[.notifyNow])
                        .font(.system(size: 12))
                        .foregroundStyle(OB.textFaint)
                }
                Text(card?.reference ?? l10n[.demoReference])
                    .font(.system(size: 14, weight: .semibold))
                Text(card?.notificationBody ?? l10n[.demoVerse])
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .foregroundStyle(OB.textMuted)
            }
            .foregroundStyle(OB.text)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(OB.line, lineWidth: 1)
        )
    }
}

// MARK: - 03-Л Лента (ветка «Меньше ленты»)

/// Вместо показа паузы — один тап. Пауза перед лентой требует собрать
/// автоматизацию в «Командах», и на этом шаге люди уходили; сама пауза
/// осталась в «Местах» и на пейволле этой ветки названа бесплатной.
///
/// Ответ никуда не уходит — ни в настройки, ни в аналитику: на экране так и
/// написано, «ответ останется на телефоне».
private struct OBFeedPage: View {
    @Environment(\.l10n) private var l10n
    let onNext: () -> Void

    @State private var hours: FeedHours?

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violet.opacity(0.2),
                                     size: 420, x: -90, y: -40))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 2)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Image("hourglass", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 124, height: 124)
                    .padding(.leading, -8)
                    .accessibilityHidden(true)

                Spacer(minLength: 12)

                OBHeading(title: l10n[.obFeedTitle], sub: l10n[.obFeedSub], italicSub: true)
                    .padding(.bottom, 20)

                VStack(spacing: 9) {
                    ForEach(FeedHours.allCases) { row($0) }
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 14) {
                    // Место под вывод держится и до ответа: иначе кнопка
                    // прыгала бы вниз от первого же тапа.
                    Text(hours.map { l10n(.obFeedInsight, l10n.count($0.daysPerYear, .daysUnit)) } ?? " ")
                        .font(OB.ui(13))
                        .lineSpacing(4)
                        .foregroundStyle(OB.textMuted)
                        .lineLimit(3, reservesSpace: true)
                        .animation(.easeOut(duration: 0.2), value: hours)

                    Button(l10n[.next], action: onNext)
                        .buttonStyle(OBButton())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }

    private func row(_ option: FeedHours) -> some View {
        let isOn = hours == option
        return Button { hours = option } label: {
            HStack {
                Text(l10n[option.titleKey])
                    .font(OB.ui(15, weight: isOn ? 600 : 500))
                    .foregroundStyle(isOn ? OB.text : OB.textMuted)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? OB.text : Color(hex: 0x7C625A))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isOn ? OB.brass.opacity(0.08) : OB.raised))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isOn ? OB.brass : OB.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - 03-Кр Вид (ветка «Красиво»)

/// Вид стиха: четыре бесплатных набора и ряд картинок.
///
/// Бесплатное включается сразу — и в приложении, и в виджетах. Платная
/// картинка не включается, а запоминается: предпросмотр её показывает, на
/// пейволле она стоит плашкой «Твой выбор», а после покупки встаёт сама.
private struct OBLookPage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    let card: Card?
    @Binding var picks: OnboardingPicks
    let onNext: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    /// Бесплатный ряд наборов. Платные наборы здесь не показываются: картинки
    /// продают вид сильнее, а два ряда замков подряд отталкивают.
    private var styles: [VerseStyle] { VerseStyle.allCases.filter { !$0.isPremium } }

    /// Бесплатные «Гималаи» первыми, за ними новые картинки — ими экран и
    /// продаёт.
    private var scenes: [VerseScene] {
        let fresh: [VerseScene] = [.ganga, .temple, .diya, .lotus]
        return VerseScene.allCases.filter { !$0.isPremium }
            + fresh
            + VerseScene.allCases.filter { $0.isPremium && !fresh.contains($0) }
    }

    private var shownScene: VerseScene? {
        picks.scene ?? (picks.style == nil ? settings.scene(for: .widgets) : nil)
    }

    private var shownStyle: VerseStyle {
        picks.style ?? settings.style(for: .widgets)
    }

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 420, x: 60, y: -120))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 2)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                OBHeading(eyebrow: l10n[.obLookEyebrow], title: l10n[.obLookTitle], sub: l10n[.obLookSub])
                    .padding(.bottom, 20)

                AppearancePreview(area: .widgets,
                                  style: shownStyle,
                                  scene: shownScene,
                                  font: settings.font(for: .widgets),
                                  text: card?.text ?? l10n[.demoVerse],
                                  reference: card?.reference ?? l10n[.demoReference],
                                  size: .medium)
                    .animation(.easeInOut(duration: 0.2), value: shownScene)
                    .animation(.easeInOut(duration: 0.2), value: shownStyle)
                    .padding(.bottom, 18)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(styles) { style in
                        Button { choose(style) } label: {
                            StyleSwatch(style: style,
                                        isSelected: shownScene == nil && shownStyle == style,
                                        isLocked: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 14)

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(scenes) { scene in
                            Button { choose(scene) } label: {
                                SceneSwatch(scene: scene,
                                            isSelected: shownScene == scene,
                                            isLocked: !entitlements.isUnlocked(scene))
                                    .frame(width: 76)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                Spacer(minLength: 16)

                Button(l10n[.next], action: onNext)
                    .buttonStyle(OBButton())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }

    private func choose(_ style: VerseStyle) {
        picks.style = nil
        picks.scene = nil
        for area in OnboardingPicks.lookAreas { settings.setStyle(style, for: area) }
    }

    private func choose(_ scene: VerseScene) {
        picks.style = nil
        if entitlements.isUnlocked(scene) {
            picks.scene = nil
            for area in OnboardingPicks.lookAreas { settings.setScene(scene, for: area) }
        } else {
            picks.scene = scene
        }
    }
}

// MARK: - 04 Первый стих

/// «Ага» без выхода из приложения: по тапу — системный вопрос, и через две
/// секунды сверху падает настоящий баннер со стихом на сегодня. Тот же стих
/// дальше будет приходить каждый день, в выбранное время или в восемь.
///
/// Отказ системе ничего не ломает: онбординг идёт дальше, стих дня остаётся
/// выключенным, а включить его потом можно в «Местах».
private struct FirstVersePage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let card: Card?
    let onNext: () -> Void

    @State private var asking = false
    @State private var sent = false

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 400, x: -60, y: 160))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 3)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                if sent {
                    OBHeading(eyebrow: l10n[.obNotifyEyebrow],
                              title: l10n[.obFirstSentTitle],
                              sub: l10n(.obFirstSentSub, timeText))
                        .transition(.opacity)
                } else {
                    OBHeading(eyebrow: l10n[.obNotifyEyebrow],
                              title: l10n[.obFirstTitle],
                              sub: l10n[.obFirstSub])

                    Spacer(minLength: 16)

                    // Так он и придёт — пока не пришёл настоящий.
                    OBBanner(card: card)
                        .opacity(asking ? 0.4 : 1)
                }

                Spacer(minLength: 16)

                VStack(spacing: 16) {
                    if sent {
                        Button(l10n[.next], action: onNext)
                            .buttonStyle(OBButton())
                    } else {
                        Button(l10n[.obFirstCta], action: send)
                            .buttonStyle(OBButton())
                            .disabled(asking)

                        Button(l10n[.notNow], action: onNext)
                            .buttonStyle(OBLink())
                            .disabled(asking)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
        .animation(.easeInOut(duration: 0.3), value: sent)
    }

    private var timeText: String {
        ClockTime.text(minutes: settings.dailyVerseMinutes, locale: l10n.locale)
    }

    private func send() {
        asking = true
        Task {
            let granted = await settings.turnOnDailyVerse(source: "onboarding")
            guard granted, let card else {
                asking = false
                onNext()
                return
            }
            Reminders.sendFirstVerse(card)
            // Заголовок меняется вместе с приходом баннера, а не раньше:
            // «уже пришёл ↑» над пустым верхом экрана выглядел бы обманом.
            try? await Task.sleep(for: .seconds(2.2))
            asking = false
            sent = true
        }
    }
}

// MARK: - 05 Иконка

/// Второе «ага»: иконка меняется по тапу, и iOS сама показывает «Вы изменили
/// иконку». Бесплатные — основная и «Голубь» — ставятся сразу. Платная
/// запоминается: на пейволле ветки «Красиво» она стоит плашкой, а после
/// покупки встаёт сама.
private struct OBIconPage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    @Binding var pick: AppIcon?
    let onNext: () -> Void

    /// Четыре в ряд: двенадцать иконок тремя рядами помещаются на экран
    /// вместе с заголовком и кнопкой.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var current: AppIcon { AppIcon(rawValue: settings.appIcon) ?? .default }

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violet.opacity(0.2),
                                     size: 440, x: 80, y: 260))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 4)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                OBHeading(eyebrow: l10n[.obIconEyebrow], title: l10n[.obIconTitle], sub: l10n[.obIconSub])
                    .padding(.bottom, 22)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(AppIcon.allCases) { tile($0) }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 16) {
                    Button(l10n[.next], action: onNext)
                        .buttonStyle(OBButton())

                    Button(l10n[.obIconKeep], action: keepDefault)
                        .buttonStyle(OBLink())
                }
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            // Только колонка: сетку при нехватке высоты забирает своя прокрутка.
            .readableColumn()
        }
    }

    private func tile(_ icon: AppIcon) -> some View {
        let unlocked = entitlements.isUnlocked(icon)
        let isSelected = (pick ?? current) == icon
        let name = l10n[icon.titleKey] + (isSelected && !unlocked ? " · Pro" : "")
        return Button { choose(icon, unlocked: unlocked) } label: {
            VStack(spacing: 7) {
                IconSwatch(icon: icon, isLocked: !unlocked, cornerRadius: 17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(isSelected ? OB.brass : .clear, lineWidth: 2)
                    )
                Text(name)
                    .font(OB.ui(10.5, weight: isSelected ? 600 : 400))
                    .foregroundStyle(isSelected ? OB.text : OB.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n[icon.titleKey] + (unlocked ? "" : ", Pro"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func choose(_ icon: AppIcon, unlocked: Bool) {
        guard unlocked else {
            pick = icon
            return
        }
        pick = nil
        guard icon != current else { return }
        settings.appIcon = icon.rawValue
        AppIconSwitcher.apply(icon)
    }

    private func keepDefault() {
        pick = nil
        if current != .default {
            settings.appIcon = AppIcon.default.rawValue
            AppIconSwitcher.apply(.default)
        }
        onNext()
    }
}

// MARK: - 06 Виджет

/// Единственный шаг вне приложения. Вернулся с виджетом — перепись при выходе
/// на передний план (`RootView`) отмечает поверхность, и шаг сам сменяется
/// «Готово». Не дождались переписи — хватает и «Поставил» в инструкции.
private struct OBWidgetPage: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let card: Card?
    let onInstalled: () -> Void
    let onLater: () -> Void

    @State private var showsInstruction = false
    @State private var finished = false

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 400, x: 60, y: 180))

            VStack(alignment: .leading, spacing: 0) {
                OBProgress(step: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                OBHeading(eyebrow: l10n[.obWidgetEyebrow], title: l10n[.obWidgetTitle], sub: l10n[.obWidgetSub])

                Spacer(minLength: 10)

                OBLockPreview(text: card?.text ?? l10n[.demoVerse],
                              reference: card?.reference ?? l10n[.demoReference])
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 10)

                VStack(spacing: 16) {
                    Button(l10n[.obWidgetCta]) { showsInstruction = true }
                        .buttonStyle(OBButton())

                    Button(l10n[.obWidgetLater], action: onLater)
                        .buttonStyle(OBLink())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            // Макет экрана блокировки здесь фиксированный, 252×352, и на
            // низком экране вместе с заголовком и кнопками в высоту не влезает.
            .readableColumn()
            .fitOrScroll()
        }
        .sheet(isPresented: $showsInstruction) {
            InstructionSheet(surface: .lockScreen) {
                settings.markInstalled(.lockScreen)
                finish()
            }
        }
        .onChange(of: settings.enabledSurfaces) { old, new in
            let added = new.subtracting(old)
            if added.contains(.lockScreen) || added.contains(.homeScreen) { finish() }
        }
    }

    /// И перепись, и «Поставил» могут сработать оба — «Готово» показывается
    /// один раз.
    private func finish() {
        guard !finished else { return }
        finished = true
        showsInstruction = false
        onInstalled()
    }
}

/// Экран блокировки с виджетом — так это будет выглядеть у человека.
struct OBLockPreview: View {
    @Environment(\.l10n) private var l10n
    let text: String
    let reference: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(l10n.mockDate)
                    .font(.system(size: 12))
                    .foregroundStyle(OB.brass.opacity(0.67))
                Text("9:41")
                    .font(.system(size: 62, weight: .medium))
                    .spaced(-2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                PlainVerse(text: text, size: 15)
                    .foregroundStyle(OB.text)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(reference.uppercased())
                    .font(OB.ui(9, weight: 600))
                    .spaced(1.1)
                    .foregroundStyle(OB.brass)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(OB.ink.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(OB.brass.opacity(0.4), lineWidth: 1))

            Spacer(minLength: 0)
        }
        .padding(.top, 34)
        .padding(.horizontal, 18)
        .frame(width: 252, height: 352)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: OB.violetDeep, location: 0),
                    .init(color: Color(hex: 0xE68B1C), location: 0.5),
                    .init(color: Color(hex: 0x28101A), location: 1),
                ], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous)
            .strokeBorder(Color(hex: 0x7A3A40), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 25, y: 22)
    }
}

// MARK: - 06b Готово

/// Награда за поставленный виджет. Собран как первый слайд: та же лампа, но
/// пламя ярче и с искрами.
private struct DonePage: View {
    @Environment(\.l10n) private var l10n
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            OBBackground(stops: [
                .init(color: Color(hex: 0x421720), location: 0),
                .init(color: Color(hex: 0x28101A), location: 0.5),
                .init(color: OB.ink, location: 1),
            ])

            OBPoster(drop: 40) {
                Image("done", bundle: .module).resizable().scaledToFill()
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("D E E P A M")
                    .font(OB.ui(12, weight: 600))
                    .kerning(3.4)
                    .foregroundStyle(OB.brass)
                    .padding(.top, 16)

                Spacer(minLength: 24)

                OBHeading(eyebrow: l10n[.obDoneEyebrow], title: l10n[.obDoneTitle])
                    .padding(.bottom, 24)

                VStack(spacing: 14) {
                    Button(l10n[.next], action: onNext)
                        .buttonStyle(OBButton())

                    Text(l10n[.obDoneFooter])
                        .font(OB.ui(11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OB.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }
}

// MARK: - 07 Почему

/// Цифра перед ценой. Без неё пейволл читается в пустоте: непонятно, много
/// двадцать пять долларов в год или мало, — а рядом с числом разблокировок
/// вопрос звучит иначе.
private struct WhyPage: View {
    @Environment(\.l10n) private var l10n
    let onNext: () -> Void

    var body: some View {
        ZStack {
            OBBackground(stops: [
                .init(color: Color(hex: 0x28101A), location: 0),
                .init(color: OB.ink, location: 1),
            ], glow: .init(color: OB.violet.opacity(0.2), size: 470, x: -40, y: 190))

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text(l10n[.obWhyLead])
                        .font(OB.ui(17))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OB.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(l10n[.obWhyNumber])
                        .font(OB.display(64))
                        .spaced(-2.5)
                        .foregroundStyle(OB.brass)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(l10n[.obWhyQuestion])
                        .font(OB.display(27))
                        .spaced(-0.4)
                        .lineSpacing(OB.spacing(27, lineHeight: 1.2))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OB.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: .infinity)

                VStack(spacing: 14) {
                    Text(l10n[.obWhySource])
                        .font(OB.ui(11.5))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OB.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(l10n[.obWhyCta], action: onNext)
                        .buttonStyle(OBButton())
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }
}

// MARK: - 08 Разрешение на отслеживание

/// Объяснение перед системным окном ATT.
///
/// Своё «Разрешить» здесь рисовать нельзя — правило 5.1.1(iv) запрещает
/// окна, похожие на системное, и подталкивание к ответу. Поэтому кнопка одна,
/// «Продолжить», и честный рассказ, зачем вопрос: что уходит в Meta и что
/// нет. Ответ на дальнейший путь не влияет — онбординг идёт дальше при
/// любом.
private struct OBTrackingPage: View {
    @Environment(\.l10n) private var l10n
    let onNext: () -> Void

    @State private var asking = false

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 400, x: 60, y: -120))

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n[.obTrackEyebrow])
                        .font(OB.ui(10, weight: 600))
                        .spaced(2)
                        .foregroundStyle(OB.brass)

                    Text(l10n[.obTrackTitle])
                        .font(OB.display(34))
                        .spaced(-0.7)
                        .lineSpacing(OB.spacing(34, lineHeight: 1.1))
                        .foregroundStyle(OB.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(l10n[.obTrackSub])
                        .font(OB.ui(14))
                        .lineSpacing(5)
                        .foregroundStyle(OB.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 24)

                Button(l10n[.obTrackCta], action: ask)
                    .buttonStyle(OBButton())
                    .disabled(asking)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }

    private func ask() {
        asking = true
        Task {
            await AdTracking.prompt?()
            onNext()
        }
    }
}
