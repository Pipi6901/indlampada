import DeepamCore
import SwiftUI

/// Экран «Вид» — макеты 11, 11a, 11b.
///
/// Три области под одним переключателем. У приложения и виджетов настраивается
/// набор цветов, у экрана блокировки — нет: там цвет задаёт система, и вместо
/// наборов настраиваются длина строки, шрифт и выравнивание.
struct LookScreen: View {
    @Environment(\.theme) private var theme
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    /// Стих для предпросмотра — настоящий, а не выдуманный: человек
    /// настраивает то, что реально увидит.
    let sample: Card?
    /// Тур ждёт выбора оформления — сначала для приложения, потом для виджетов.
    var coach: Coach? = nil

    @Environment(\.l10n) private var l10n
    @Environment(\.paywallHook) private var hook
    @Environment(\.openURL) private var openURL
    @State private var area: AppearanceArea = .app
    @State private var showsPaywall = false
    @State private var paywallPick: PaywallPick?
    @State private var showsLanguage = false
    @State private var showsFont = false
    @State private var showsIcon = false
    @State private var showsSubscription = false
    /// Подпись вместо версии на пару секунд: «токен скопирован» или причина,
    /// почему его нет.
    @State private var tokenNote: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(l10n[.lookTitle])
                    .font(theme.display(30))
                    .foregroundStyle(theme.text)

                Segmented(selection: $area, items: AppearanceArea.allCases) { l10n[$0.titleKey] }
                    .coachAnchors([.areas, .switchToWidgets])

                // На вкладке «Приложение» предпросмотра нет намеренно: набор
                // красит сам экран, и отдельная карточка показывала бы то же
                // самое второй раз.
                if area != .app { preview }

                if area == .widgets {
                    labelled(l10n[.size]) {
                        Segmented(selection: $settings.widgetSize,
                                  items: WidgetSize.allCases) { widgetSizeName($0) }
                    }
                    labelled(l10n[.alignment]) {
                        Segmented(selection: alignmentBinding,
                                  items: VerseAlignment.allCases) { l10n[$0.titleKey] }
                    }
                }

                if area.appliesColor {
                    // Тур подсвечивает оба ряда разом: выбор один, сделанный
                    // цветом или картинкой, и подсветить половину значило бы
                    // сказать, что вторая не считается.
                    VStack(alignment: .leading, spacing: 20) {
                        styles
                        scenes
                    }
                    .coachAnchors([.appStyle, .widgetStyle])
                } else {
                    lockControls
                }

                rows
            }
            .padding(.horizontal, 26)
            // Колонка внутри прокрутки, а не снаружи: так листается вся ширина
            // экрана, включая поля по бокам колонки на iPhone Duo.
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .scrollFade()
        .onChange(of: area) { _, area in
            if area == .widgets { coach?.completed(.switchToWidgets) }
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallSheet(settings: settings, entitlements: entitlements, source: .look, pick: paywallPick)
        }
        .sheet(isPresented: $showsLanguage) { LanguageSheet(settings: settings) }
        .sheet(isPresented: $showsFont) {
            FontSheet(settings: settings, entitlements: entitlements,
                      area: area, sample: sampleText)
        }
        .sheet(isPresented: $showsIcon) {
            IconSheet(settings: settings, entitlements: entitlements)
        }
        .sheet(isPresented: $showsSubscription) {
            if let center = hook.customerCenter { center() }
        }
    }

    // MARK: - Предпросмотр

    private var preview: some View {
        labelled(area == .widgets ? "\(l10n[.preview]) · \(widgetSizeName(settings.widgetSize))" : l10n[.preview]) {
            AppearancePreview(
                area: area,
                style: settings.style(for: area),
                scene: settings.scene(for: area),
                font: settings.font(for: area),
                text: sampleText,
                reference: sample?.reference ?? "",
                size: settings.widgetSize,
                alignment: settings.alignment(for: area),
                length: settings.lockLength
            )
        }
    }

    // MARK: - Наборы

    private var styles: some View {
        labelled(l10n[.colourSets]) {
            LazyVGrid(columns: columns, spacing: 12) {
            ForEach(VerseStyle.allCases) { style in
                let unlocked = entitlements.isUnlocked(style)
                Button {
                    if unlocked {
                        settings.setStyle(style, for: area)
                        styleChosen()
                    } else {
                        paywallPick = PaywallPick(.sets, name: l10n[style.titleKey])
                        showsPaywall = true
                    }
                } label: {
                    // Выбранная картинка снимает выделение с цвета: это один
                    // выбор, сделанный двумя способами. Значение цвета при этом
                    // остаётся — на него возвращаются, когда картинку снимут, —
                    // поэтому «ничего не выбрано» приходится выводить из
                    // картинки, а не из пустого набора.
                    StyleSwatch(style: style,
                                isSelected: settings.scene(for: area) == nil
                                    && settings.style(for: area) == style,
                                isLocked: !unlocked)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n[style.titleKey] + (unlocked ? "" : ", " + l10n[.subscribe]))
                }
            }
        }
    }

    /// Второй ряд плиток — фоны-изображения. Тот же выбор, что и цвет: одно
    /// снимает другое, поэтому и сетка та же, 4×2.
    private var scenes: some View {
        labelled(l10n[.imageSets]) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(VerseScene.allCases) { scene in
                    let unlocked = entitlements.isUnlocked(scene)
                    Button {
                        if unlocked {
                            settings.setScene(scene, for: area)
                            styleChosen()
                        } else {
                            paywallPick = PaywallPick(.pictures, name: l10n[scene.titleKey])
                            showsPaywall = true
                        }
                    } label: {
                        SceneSwatch(scene: scene,
                                    isSelected: settings.scene(for: area) == scene,
                                    isLocked: !unlocked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n[scene.titleKey] + (unlocked ? "" : ", " + l10n[.subscribe]))
                }
            }
        }
    }

    /// Выбрали оформление — цветом или картинкой, без разницы. Тур ждёт этого
    /// на двух шагах, по одному на область.
    private func styleChosen() {
        switch area {
        case .app: coach?.completed(.appStyle)
        case .widgets: coach?.completed(.widgetStyle)
        case .lockScreen: break
        }
    }

    // MARK: - Экран блокировки

    /// Заметка про цвет из макета переписана в одну строку под превью.
    /// Развёрнутый блок с иконкой занимал четверть экрана и объяснял то, что
    /// и так видно: наборов цвета в этой вкладке просто нет.
    private var lockControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(l10n[.lockColorNote])
                .font(theme.ui(12))
                .foregroundStyle(theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            labelled(l10n[.verseLength]) {
                Segmented(selection: $settings.lockLength,
                          items: VerseLength.allCases) { l10n[$0.titleKey] }
            }
            DisclosureRow(title: l10n[.font], value: fontName) { showsFont = true }
            labelled(l10n[.alignment]) {
                Segmented(selection: alignmentBinding,
                          items: VerseAlignment.allCases) { l10n[$0.titleKey] }
            }
        }
    }

    // MARK: - Строки внизу

    @ViewBuilder
    private var rows: some View {
        VStack(spacing: 10) {
            if area != .lockScreen {
                DisclosureRow(title: l10n[.font], value: fontName) { showsFont = true }
            }
            if area == .app {
                DisclosureRow(title: l10n[.appIconTitle], value: iconName) { showsIcon = true }
            }
            if area == .app, hook.customerCenter != nil {
                // Появляется только когда подставлен настоящий экран RevenueCat:
                // вести человека в пустоту хуже, чем не показывать строку.
                DisclosureRow(title: l10n[.manageSubscription],
                              value: "") { showsSubscription = true }
            }
            if area == .app {
                DisclosureRow(title: l10n[.languageAndEdition],
                              value: (settings.language ?? .detect()).shortPair) {
                    showsLanguage = true
                }
            }
            if area == .app { originalRow }
            if area == .app {
                // Страница отзыва открывается всегда — в отличие от системного
                // окна, которое iOS показывает не чаще трёх раз в год.
                DisclosureRow(title: l10n[.rateApp], value: "") {
                    EventLog.log(.reviewPrompt(source: "look"))
                    openURL(ReviewPrompt.writeReviewURL)
                }
            }
            if area == .app { analyticsRow }
            if area == .app { versionFooter }
        }
        .padding(.bottom, 8)
    }

    /// Санскритский оригинал над переводом. По умолчанию выключен, включается здесь.
    private var originalRow: some View {
        HStack {
            Text(l10n[.showOriginal])
                .font(theme.ui(14))
                .foregroundStyle(theme.textMuted)
            Spacer()
            Toggle("", isOn: Binding(
                get: { settings.showsOriginal },
                set: { settings.showsOriginal = $0 }
            ))
            .labelsHidden()
            .scaleEffect(0.75)
            .frame(width: 38, height: 22)
            .tint(theme.accent)
            .accessibilityLabel(l10n[.showOriginal])
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Capsule().fill(theme.raised))
    }

    /// Версия и сборка — для поддержки. Долгое нажатие копирует токен
    /// уведомлений: с ним консоль Firebase шлёт пробную рассылку на один
    /// телефон, не задевая остальных. Людям это не нужно, поэтому спрятано.
    private var versionFooter: some View {
        Text(tokenNote ?? Self.versionText)
            .font(theme.ui(11))
            .foregroundStyle(theme.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .multilineTextAlignment(.center)
            .onLongPressGesture {
                Task {
                    switch await PushToken.fetch?() {
                    case .success(let token):
                        Platform.copy(token)
                        tokenNote = l10n[.pushTokenCopied]
                    case .failure(let error):
                        tokenNote = error.message
                    case nil:
                        tokenNote = "—"
                    }
                    // Причину надо успеть прочитать — она длиннее «скопирован».
                    try? await Task.sleep(for: .seconds(6))
                    tokenNote = nil
                }
            }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "Deepam \(version) (\(build))"
    }

    /// «Помогать улучшать Deepam». Последней строкой и только на вкладке
    /// «Приложение»: это настройка приложения, а не оформления.
    private var analyticsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n[.analyticsTitle])
                    .font(theme.ui(14))
                    .foregroundStyle(theme.textMuted)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { settings.analyticsEnabled },
                    set: {
                        settings.analyticsEnabled = $0
                        EventLog.setCollectionEnabled($0)
                    }
                ))
                .labelsHidden()
                .scaleEffect(0.75)
                .frame(width: 38, height: 22)
                .tint(theme.accent)
                .accessibilityLabel(l10n[.analyticsTitle])
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Capsule().fill(theme.raised))

            Text(l10n[.analyticsNote])
                .font(theme.ui(11))
                .foregroundStyle(theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
    }

    /// Выравнивание живёт в словаре по областям, а `Segmented` требует
    /// привязку — сводим одно к другому здесь.
    private var alignmentBinding: Binding<VerseAlignment> {
        Binding(get: { settings.alignment(for: area) },
                set: { settings.setAlignment($0, for: area) })
    }

    /// У StandBy названия для перевода нет — это имя режима iOS.
    private func widgetSizeName(_ size: WidgetSize) -> String {
        size.titleKey.map { l10n[$0] } ?? "StandBy"
    }

    /// Название выбранного шрифта для строки настроек.
    private var fontName: String {
        settings.font(for: area) == .system ? l10n[.systemFont] : settings.font(for: area).title
    }

    /// Название выбранной иконки для строки настроек.
    private var iconName: String {
        l10n[(AppIcon(rawValue: settings.appIcon) ?? .default).titleKey]
    }

    /// Образец для предпросмотра и списка шрифтов — настоящий стих, а не
    /// выдуманная строка: человек настраивает то, что реально увидит.
    private var sampleText: String {
        sample?.text ?? l10n[.heroTitle]
    }

    private func labelled<Content: View>(_ title: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(theme.ui(10, weight: 600))
                .spaced(1.2)
                .foregroundStyle(theme.textFaint)
            content()
        }
    }
}

extension AppLocale {
    var shortPair: String { "\(nativeName) · \(editionShort)" }
}
