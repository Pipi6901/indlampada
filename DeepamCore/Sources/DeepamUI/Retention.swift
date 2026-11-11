import DeepamCore
import Observation
import SwiftUI

// MARK: - Скидка после закрытого пейволла

/// Второй шанс: годовой со скидкой на первый год.
///
/// Показывается один раз — сразу после того, как новый человек закрыл пейволл
/// онбординга, не начав триал. Не раньше и не повторно: скидка, которая
/// появляется при каждом закрытии, учит закрывать пейволл.
///
/// Это тоже экран оплаты, поэтому на нём всё, что требует правило 3.1.2:
/// цена первого года, цена продления, автоматическое продление и ссылки на
/// условия и политику.
struct WelcomeOfferScreen: View {
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.paywallStore) private var store
    let entitlements: any EntitlementStore
    let offer: WelcomeOffer

    @State private var viewLogged = false

    var body: some View {
        ZStack(alignment: .top) {
            OBBackground(stops: [
                .init(color: Color(hex: 0x3E2E49), location: 0),
                .init(color: Color(hex: 0x261C2D), location: 0.5),
                .init(color: OB.ink, location: 1),
            ], glow: .init(color: OB.violet.opacity(0.29), size: 440, x: -40, y: -160))

            // Подарок — та же лампада, что на первом слайде, с винной лентой.
            OBPoster(drop: 20) {
                Image("gift", bundle: .module).resizable().scaledToFill()
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 280)

                VStack(alignment: .leading, spacing: 12) {
                    Text(l10n[.welcomeEyebrow])
                        .font(OB.ui(10, weight: 600))
                        .spaced(2)
                        .foregroundStyle(OB.brass)

                    Text(l10n(.welcomeTitle, offer.introPrice))
                        .font(OB.display(36))
                        .spaced(-0.7)
                        .lineSpacing(OB.spacing(36, lineHeight: 1.1))
                        .foregroundStyle(OB.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(l10n(.welcomeSub, offer.regularPrice))
                        .font(OB.ui(15))
                        .lineSpacing(5)
                        .foregroundStyle(OB.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    Button {
                        guard let store else { return }
                        Task { await store.purchaseWelcome() }
                    } label: {
                        ZStack {
                            Text(l10n(.welcomeCta, offer.introPrice))
                                .opacity(store?.isPurchasing == true ? 0 : 1)
                            if store?.isPurchasing == true {
                                ProgressView().tint(OB.onBrass)
                            }
                        }
                    }
                    .buttonStyle(OBButton())
                    .disabled(store?.isPurchasing == true)

                    if let error = store?.lastError {
                        Text(error)
                            .font(OB.ui(12))
                            .foregroundStyle(OB.textMuted)
                            .multilineTextAlignment(.center)
                    }

                    Text(l10n(.welcomeTerms, offer.regularPrice))
                        .font(OB.ui(11))
                        .foregroundStyle(OB.textFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(l10n[.welcomeNo]) { dismiss() }
                        .font(OB.ui(14, weight: 500))
                        .foregroundStyle(OB.textMuted)
                        .padding(.vertical, 6)
                        .buttonStyle(.plain)

                    HStack(spacing: 7) {
                        Button(l10n[.pwTerms]) { openURL(Legal.terms) }
                        Text("·")
                        Button(l10n[.pwPrivacy]) { openURL(Legal.privacy) }
                    }
                    .buttonStyle(.plain)
                    .underline()
                    .font(OB.ui(11))
                    .foregroundStyle(OB.textFaint)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
            .readableColumn()
            .fitOrScroll()
        }
        .onChange(of: entitlements.isSubscribed) { _, isSubscribed in
            if isSubscribed { dismiss() }
        }
        .onAppear {
            guard !viewLogged else { return }
            viewLogged = true
            EventLog.log(.paywallView(.welcome))
        }
    }
}

// MARK: - Почему отменил триал

/// Варианты ответа. Строка уходит в аналитику как есть.
enum CancelReason: String, CaseIterable, Identifiable {
    case price
    case notUsing = "not_using"
    case freeEnough = "free_enough"
    case notWhat = "not_what"
    case justLooking = "just_looking"
    case other

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .price: .reasonPrice
        case .notUsing: .reasonUnused
        case .freeEnough: .reasonFreeEnough
        case .notWhat: .reasonNotWhat
        case .justLooking: .reasonJustLooking
        case .other: .reasonOther
        }
    }
}

/// «Пробная неделя отменена — почему?»
///
/// Большинство отменяет триал в настройках iPhone, мимо приложения, и опрос
/// RevenueCat этих людей не видит. Поэтому приложение замечает отмену само —
/// по снимку подписки, где продление выключено, а бесплатный период ещё
/// идёт, — и спрашивает один раз, при следующем открытии.
///
/// Причин можно отметить несколько: уходят редко по одной — «дорого» и «редко
/// открываю» обычно идут вместе. Отправка — отдельной кнопкой, чтобы случайное
/// касание не закрывало лист. Поля для своего текста нет: свободный текст в
/// GA4 слать нельзя, а длинную форму всё равно никто не заполняет.
struct CancelReasonSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var picked: Set<CancelReason> = []
    @State private var answered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n[answered ? .cancelThanks : .cancelTitle])
                .font(theme.display(24))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            if !answered {
                Text(l10n[.cancelSub])
                    .font(theme.ui(13))
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(CancelReason.allCases) { reason in
                        row(reason)
                    }
                }

                Button(l10n[.cancelSend]) { send() }
                    .buttonStyle(PrimaryButton())
                    .disabled(picked.isEmpty)
                    .opacity(picked.isEmpty ? 0.45 : 1)
                    .padding(.top, 4)

                Button(l10n[.cancelSkip]) { skip() }
                    .font(theme.ui(13, weight: 500))
                    .foregroundStyle(theme.textFaint)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
        // Смахнули лист — тоже ответ: значит, отвечать не стали.
        .onDisappear { if !answered { EventLog.log(.cancelReason(reason: "skip", source: "sheet", wasTrial: true)) } }
    }

    /// Строка-переключатель: касание отмечает или снимает, лист не закрывается.
    private func row(_ reason: CancelReason) -> some View {
        let isOn = picked.contains(reason)
        return Button {
            if isOn { picked.remove(reason) } else { picked.insert(reason) }
        } label: {
            HStack(spacing: 12) {
                Text(l10n[reason.titleKey])
                    .font(theme.ui(14))
                    .foregroundStyle(theme.text)
                Spacer(minLength: 0)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? theme.accent : theme.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Capsule().fill(theme.raised))
            .overlay(Capsule().strokeBorder(isOn ? theme.accent : .clear, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    /// Каждая причина — отдельным событием, как ответы онбординга: так в GA4
    /// считается, сколько людей назвали каждую.
    private func send() {
        guard !answered, !picked.isEmpty else { return }
        answered = true
        for reason in CancelReason.allCases where picked.contains(reason) {
            EventLog.log(.cancelReason(reason: reason.rawValue, source: "sheet", wasTrial: true))
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }

    private func skip() {
        guard !answered else { return }
        answered = true
        EventLog.log(.cancelReason(reason: "skip", source: "sheet", wasTrial: true))
        dismiss()
    }
}

// MARK: - Тап по уведомлению

/// Куда вести после тапа по уведомлению.
///
/// Делегат уведомлений живёт в приложении, а экраны — здесь, поэтому между
/// ними общий объект: делегат кладёт, куда вести, корневой экран открывает.
/// Так работают и свои уведомления («поставь на рабочий стол»), и рассылки
/// из Firebase — ключи их данных описаны в `PushAction`.
@MainActor
@Observable
public final class NotificationRoute {
    public static let shared = NotificationRoute()

    public var surface: Surface?
    /// Платный экран и предложение RevenueCat для него.
    public var paywall: PushPaywall?
    public var tab: Tab?

    private init() {}

    public func open(_ action: PushAction) {
        if let name = action.tab, let tab = Tab(rawValue: name) { self.tab = tab }
        if let surface = action.surface { self.surface = surface }
        if action.paywall { paywall = PushPaywall(offering: action.offering) }
    }
}

/// Платный экран из рассылки.
public struct PushPaywall: Hashable, Sendable {
    /// `nil` — текущее предложение.
    public let offering: String?
}
