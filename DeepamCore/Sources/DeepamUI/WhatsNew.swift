import DeepamCore
import SwiftUI

/// «Что нового» — один раз после обновления, блок «Что нового в 1.0.2» в
/// файле дизайна.
///
/// Пуш до тех, кто обновился, доходит только у разрешивших уведомления, а этот
/// экран видит каждый, кто открыл приложение. Поэтому новинки показываются
/// здесь, и здесь же — вопрос про уведомления тем, кого ещё не спрашивали:
/// кто ставил приложение до 1.0.1, онбординг с этим шагом не видел вовсе.
///
/// Страницы листаются свайпом, оформление — как у онбординга. Страницы
/// уведомлений нет у тех, кто уже отказал: второй раз iOS окно не покажет, а
/// переключатель новостей без уведомлений ничего не даёт.
struct WhatsNewFlow: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    let card: Card?
    let onFinish: () -> Void

    enum Page: String {
        case icons, pictures, daily
    }

    @State private var pages: [Page] = [.icons, .pictures]
    @State private var page: Page? = .icons
    @State private var authorization: NotificationAuthorization?

    var body: some View {
        ZStack {
            OBBackground(stops: obDeep,
                         glow: .init(color: OB.violetDeep.opacity(0.3),
                                     size: 420, x: 60, y: -120))

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages, id: \.self) { page in
                        content(page)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
        }
        .task {
            let answer = await Reminders.authorization()
            authorization = answer
            if answer != .denied { pages.append(.daily) }
        }
        .onChange(of: page, initial: true) { _, page in
            guard let page, let index = pages.firstIndex(of: page) else { return }
            EventLog.log(.whatsNewStep(index: index, name: page.rawValue))
        }
    }

    @ViewBuilder
    private func content(_ page: Page) -> some View {
        switch page {
        case .icons:
            WNIconsPage(settings: settings, entitlements: entitlements,
                        top: topRow(page), onNext: { next(after: page) }, onSkip: skip)
        case .pictures:
            WNPicturesPage(settings: settings, entitlements: entitlements, card: card,
                           top: topRow(page), onNext: { next(after: page) }, onSkip: skip)
        case .daily:
            WNDailyPage(settings: settings, card: card, authorization: authorization,
                        top: topRow(page), onFinish: onFinish)
        }
    }

    /// Точки страниц и крестик — крестик закрывает весь экран.
    private func topRow(_ page: Page) -> some View {
        let current = pages.firstIndex(of: page) ?? 0
        return HStack {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? OB.brass : OB.line)
                        .frame(width: index == current ? 26 : 14, height: 4)
                }
            }
            Spacer()
            Button(action: onFinish) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OB.textFaint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n[.close])
        }
        .padding(.trailing, -12)
    }

    private func next(after page: Page) {
        guard let index = pages.firstIndex(of: page), index + 1 < pages.count else {
            onFinish()
            return
        }
        withAnimation(.snappy) { self.page = pages[index + 1] }
    }

    /// «Пропустить» листает к уведомлениям, а не закрывает: ради них экран во
    /// многом и затевался. Страницы уведомлений нет — закрывает.
    private func skip() {
        if pages.last == .daily {
            withAnimation(.snappy) { page = .daily }
        } else {
            onFinish()
        }
    }
}

// MARK: - Новые иконки

/// Голубь ставится по тапу сразу. Платная — пейволл «Твой выбор», и после
/// покупки иконка встаёт сама, когда лист закроется.
private struct WNIconsPage<Top: View>: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    let top: Top
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var paywallFor: AppIcon?
    @State private var pending: AppIcon?

    private let icons: [AppIcon] = [.night, .lotus, .om, .dawn, .temple]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var current: AppIcon { AppIcon(rawValue: settings.appIcon) ?? .default }

    var body: some View {
        WNPage(top: top) {
            OBHeading(eyebrow: l10n[.wnIconsEyebrow], title: l10n[.wnIconsTitle], sub: l10n[.wnIconsSub])

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(icons) { tile($0) }
            }
            .padding(.top, 22)
        } bottom: {
            Button(l10n[.next], action: onNext)
                .buttonStyle(OBButton())
            Button(l10n[.wnSkip], action: onSkip)
                .buttonStyle(OBLink())
        }
        .sheet(item: $paywallFor, onDismiss: applyBought) { icon in
            PaywallSheet(settings: settings, entitlements: entitlements, source: .whatsNew,
                         pick: PaywallPick(.icons, name: l10n[icon.titleKey]))
        }
    }

    private func tile(_ icon: AppIcon) -> some View {
        let isSelected = current == icon
        let locked = !entitlements.isUnlocked(icon)
        let name = l10n[icon.titleKey] + (icon.isPremium ? "" : " · " + l10n[.wnFree])
        return Button { choose(icon) } label: {
            VStack(spacing: 8) {
                WNArt(image: icon.previewAsset ?? "", isPro: locked, cornerRadius: 22)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isSelected ? OB.brass : .clear, lineWidth: 2))
                Text(name)
                    .font(OB.ui(11, weight: isSelected ? 600 : 400))
                    .foregroundStyle(isSelected ? OB.text : OB.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n[icon.titleKey] + (locked ? ", Pro" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func choose(_ icon: AppIcon) {
        guard entitlements.isUnlocked(icon) else {
            pending = icon
            paywallFor = icon
            return
        }
        apply(icon)
    }

    private func apply(_ icon: AppIcon) {
        settings.appIcon = icon.rawValue
        AppIconSwitcher.apply(icon)
    }

    /// Лист закрыт. Купили — ставим ту иконку, ради которой открывали.
    /// `paywallFor` к этому моменту лист уже обнулил, поэтому она запомнена
    /// отдельно.
    private func applyBought() {
        defer { pending = nil }
        guard let pending, entitlements.isUnlocked(pending) else { return }
        apply(pending)
    }
}

// MARK: - Новые картинки

/// Тап — предпросмотр со стихом на сегодня: так картинка продаёт себя лучше
/// любой плитки. С Pro оттуда же ставится фоном.
private struct WNPicturesPage<Top: View>: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    let card: Card?
    let top: Top
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var preview: VerseScene?

    private let scenes: [VerseScene] = [.ganga, .temple, .diya, .lotus]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 13), count: 2)

    var body: some View {
        WNPage(top: top) {
            OBHeading(eyebrow: l10n[.wnPicturesEyebrow], title: l10n[.wnPicturesTitle], sub: l10n[.wnPicturesSub])

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(scenes) { scene in
                    Button { preview = scene } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            WNArt(image: "\(scene.asset)-square",
                                  isPro: !entitlements.isUnlocked(scene), cornerRadius: 18)
                            Text(l10n[scene.titleKey])
                                .font(OB.ui(12, weight: 500))
                                .foregroundStyle(OB.textMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 22)
        } bottom: {
            Button(l10n[.next], action: onNext)
                .buttonStyle(OBButton())
            Button(l10n[.wnSkip], action: onSkip)
                .buttonStyle(OBLink())
        }
        .sheet(item: $preview) { scene in
            ScenePreviewSheet(settings: settings, entitlements: entitlements, scene: scene, card: card)
        }
    }
}

/// Картинка со стихом на сегодня — во весь лист, как на «Сегодня».
private struct ScenePreviewSheet: View {
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    let scene: VerseScene
    let card: Card?

    @State private var showsPaywall = false

    private var ink: Color { Color(hex: scene.palette.text) }
    private var tint: Color { Color(hex: scene.palette.accent) }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                SceneBackground(scene: scene, variant: .tall)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(l10n[scene.titleKey].uppercased())
                        .font(OB.ui(11, weight: 600))
                        .spaced(2)
                        .foregroundStyle(tint)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ink.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n[.close])
                }
                .padding(.trailing, -12)

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 14) {
                    PlainVerse(text: card?.text ?? l10n[.demoVerse], size: 26)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text((card?.reference ?? l10n[.demoReference]).uppercased())
                        .font(OB.ui(10, weight: 600))
                        .spaced(2)
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 24)

                Button(entitlements.isUnlocked(scene) ? l10n[.wnSetPicture] : l10n[.wnUnlockPicture]) {
                    if entitlements.isUnlocked(scene) { apply() } else { showsPaywall = true }
                }
                .buttonStyle(OBButton())
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 26)
            .readableColumn()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsPaywall) {
            PaywallSheet(settings: settings, entitlements: entitlements, source: .whatsNew,
                         pick: PaywallPick(.pictures, name: l10n[scene.titleKey]))
        }
        // Купили — картинка встаёт сама: ради неё и платили.
        .onChange(of: entitlements.isSubscribed) { _, isSubscribed in
            if isSubscribed { apply() }
        }
    }

    private func apply() {
        for area in OnboardingPicks.lookAreas { settings.setScene(scene, for: area) }
        dismiss()
    }
}

// MARK: - Стих каждый день

/// Системный вопрос — только тем, кого ещё не спрашивали. Уже разрешили, а
/// стих дня выключен — кнопка просто включает его. Всё включено — «Готово».
///
/// Переключатель новостей по умолчанию выключен: это согласие на рекламные
/// рассылки по правилу 4.5.4, и включить его за человека нельзя.
private struct WNDailyPage<Top: View>: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let card: Card?
    let authorization: NotificationAuthorization?
    let top: Top
    let onFinish: () -> Void

    @State private var asking = false

    /// Включать нечего — остаётся только переключатель новостей.
    private var alreadyOn: Bool { authorization == .allowed && settings.dailyVerseEnabled }

    var body: some View {
        WNPage(top: top) {
            OBHeading(eyebrow: l10n[.obNotifyEyebrow], title: l10n[.wnDailyTitle],
                           sub: l10n(.wnDailySub, ClockTime.text(minutes: settings.dailyVerseMinutes,
                                                                 locale: l10n.locale)))

            VStack(spacing: 14) {
                OBBanner(card: card)
                PromoToggle(settings: settings, source: "whats_new")
            }
            .padding(.top, 24)
        } bottom: {
            if alreadyOn {
                Button(l10n[.wnDone], action: onFinish)
                    .buttonStyle(OBButton())
            } else {
                Button(l10n[.wnDailyCta], action: enable)
                    .buttonStyle(OBButton())
                    .disabled(asking)
                Button(l10n[.notNow], action: onFinish)
                    .buttonStyle(OBLink())
                    .disabled(asking)
            }
        }
    }

    private func enable() {
        asking = true
        Task {
            await settings.turnOnDailyVerse(source: "whats_new")
            asking = false
            onFinish()
        }
    }
}

/// «Новости и обновления» — карточкой на «Что нового».
private struct PromoToggle: View {
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let source: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l10n[.promoTitle])
                    .font(OB.ui(15, weight: 600))
                    .foregroundStyle(OB.text)
                Text(l10n[.promoSub])
                    .font(OB.ui(12))
                    .lineSpacing(3)
                    .foregroundStyle(OB.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(get: { settings.promoOptIn },
                                     set: { settings.setPromoOptIn($0, source: source) }))
                .labelsHidden()
                .tint(OB.violet)
                .accessibilityLabel(l10n[.promoTitle])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(OB.brass.opacity(0.07)))
    }
}

extension AppSettings {
    /// Согласие на новости — и сразу событие, чтобы в отчётах было видно, где
    /// соглашаются. Свойство `promo_optin` ставит `RootView` по изменению.
    func setPromoOptIn(_ on: Bool, source: String) {
        guard on != promoOptIn else { return }
        promoOptIn = on
        EventLog.log(.promoOptIn(on: on, source: source))
    }
}

// MARK: - Общее

/// Страница «Что нового»: точки и крестик сверху, кнопки снизу.
private struct WNPage<Top: View, Content: View, Bottom: View>: View {
    let top: Top
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            top
                .padding(.bottom, 16)
            content
            Spacer(minLength: 20)
            VStack(spacing: 16) { bottom }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.bottom, 34)
        .readableColumn()
        .fitOrScroll()
    }
}

/// Картинка новинки во весь квадрат. Платная — с плашкой PRO, но не
/// приглушённая: экран показывает новое, а не замки.
private struct WNArt: View {
    let image: String
    let isPro: Bool
    let cornerRadius: CGFloat

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(image, bundle: .module)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isPro {
                    Text("PRO")
                        .font(OB.ui(9, weight: 700))
                        .spaced(1)
                        .foregroundStyle(OB.brass)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(OB.ink.opacity(0.8)))
                        .padding(8)
                }
            }
    }
}
