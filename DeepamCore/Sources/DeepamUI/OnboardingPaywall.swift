import DeepamCore
import SwiftUI

/// Платный экран — четыре пейволла веток в блоке «Онбординг v3» макета.
///
/// Отличается от обычного списка возможностей тем, что говорит с человеком его
/// же словами: заголовок и порядок плиток — по ответу на «Что тебе сейчас
/// нужнее?», над заголовком — то, что он выбрал по дороге (темы, время,
/// иконку и картинку). Ответа нет — заголовок общий, и экран не притворяется,
/// будто что-то про человека знает. Что именно показать, решает `PaywallPitch`.
///
/// Тарифов три, по умолчанию выбран годовой: он и выгоднее, и единственный с
/// бесплатной неделей. Пожизненная покупка здесь не показывается — она осталась
/// в каталоге, но продавать её на этом экране не нужно.
///
/// Цены и покупка приходят из `PaywallStore`, а он подставляется снаружи: сам
/// интерфейс про RevenueCat не знает и линковать его не должен.
struct PaywallScreen: View {
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.paywallStore) private var store
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    /// Откуда открыли — для аналитики: видно, какой замок продаёт.
    let source: PaywallSource
    /// Что человек тапнул перед замком. Есть — над заголовком вместо ответов
    /// онбординга стоит именно это: «твой выбор — Царь Давид».
    var pick: PaywallPick? = nil
    /// Платное, выбранное на шагах онбординга, — плашки ветки «Красиво».
    var onboardingPicks: [PaywallPick] = []
    /// Предложение RevenueCat из рассылки, например акция. `nil` — текущее.
    var offering: String? = nil

    @State private var selected: PaywallPlan.Period = PaywallPlan.preferred
    /// Показ считается один раз на появление листа. `onAppear` срабатывает и
    /// при возврате на экран из-под другого листа — второй показ исказил бы
    /// конверсию пейволла в триал.
    @State private var viewLogged = false

    /// Тарифы к показу.
    ///
    /// Без магазина — заглушка: так экран можно смотреть в предпросмотрах и в
    /// сборке без сети. С магазином берём только то, что он реально отдал:
    /// показать цену, которой в App Store нет, значит соврать про деньги.
    private var plans: [PaywallPlan] {
        guard let store else { return PaywallPlan.placeholder }
        return store.plans
    }

    private var plan: PaywallPlan? {
        plans.first { $0.period == selected } ?? plans.first
    }

    private var pitch: PaywallPitch {
        PaywallPitch(source: source, picks: pick.map { [$0] } ?? onboardingPicks,
                     settings: settings, l10n: l10n)
    }

    var body: some View {
        ZStack {
            OBBackground(stops: [
                .init(color: Color(hex: 0x4A1A24), location: 0),
                .init(color: Color(hex: 0x28101A), location: 0.5),
                .init(color: OB.ink, location: 1),
            ], glow: .init(color: OB.violet.opacity(0.29), size: 440, x: 40, y: -180))

            // Пейволл свёрстан ровно в высоту макета, около 720 точек. На
            // внешнем экране iPhone Duo и на внутреннем лёжа места меньше, и без
            // прокрутки кнопка покупки и ссылки на условия уезжали за край —
            // купить нельзя, а ссылки обязаны быть видны по правилу 3.1.2.
            VStack(alignment: .leading, spacing: 0) {
                closeRow
                heading
                Spacer(minLength: 14)
                unlocks
                Spacer(minLength: 14)
                bottom
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .readableColumn()
            .fitOrScroll()
        }
        // Куплено — экран больше не нужен: и после покупки здесь же, и когда
        // подписку восстановили или оформили на другом устройстве.
        .onChange(of: entitlements.isSubscribed) { _, isSubscribed in
            if isSubscribed { dismiss() }
        }
        .onAppear {
            guard !viewLogged else { return }
            viewLogged = true
            EventLog.log(.paywallView(source, variant: pitch.variant))
        }
        // Акционные цены — только на этом показе: следующий пейволл, открытый
        // с замка, должен показать обычные.
        .onDisappear {
            guard offering != nil, let store else { return }
            Task { await store.loadPlans(offering: nil) }
        }
        .task {
            // Цены могли не успеть приехать к запуску: экран просит их сам.
            // Предложение из рассылки грузится всегда: в магазине могут лежать
            // цены текущего.
            if let store, offering != nil || store.plans.isEmpty { await store.loadPlans(offering: offering) }
            if let first = plans.first(where: { $0.period == PaywallPlan.preferred })
                ?? plans.first {
                selected = first.period
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OB.textFaint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, -12)
    }

    private var heading: some View {
        let pitch = pitch
        return VStack(alignment: .leading, spacing: 10) {
            if let eyebrow = pitch.eyebrow {
                Text(eyebrow)
                    .font(OB.ui(10, weight: 600))
                    .spaced(2)
                    .foregroundStyle(OB.brass)
            }

            if !pitch.chips.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(pitch.chips, id: \.self) { chip in
                        HStack(spacing: 6) {
                            if let symbol = chip.symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            Text(chip.text)
                                .font(OB.ui(11.5, weight: 500))
                        }
                        .foregroundStyle(OB.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(OB.brass.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(OB.brass.opacity(0.3), lineWidth: 1))
                    }
                }
            }

            Text(pitch.title)
                .font(OB.display(32))
                .spaced(-0.6)
                .lineSpacing(OB.spacing(32, lineHeight: 1.1))
                .foregroundStyle(OB.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(pitch.sub)
                .font(OB.ui(14))
                .lineSpacing(5)
                .foregroundStyle(OB.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Сетка платного набора: два ряда по три, порядок — по ветке.
    ///
    /// Светлые только две первые — то, ради чего человек сюда шёл; остальные
    /// обведены и тише. Раньше подсвечивалась одна плитка среди пяти тёмных,
    /// и она читалась как выбранная кем-то за человека. Две первые в порядке
    /// его же ветки читаются как ответ на его слова, а не как чужой выбор.
    private var unlocks: some View {
        let order = pitch.unlocks
        let rows = [Array(order.prefix(3)), Array(order.dropFirst(3))]
        return VStack(spacing: 12) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 10) {
                    ForEach(row) { tile($0, lit: order.prefix(2).contains($0)) }
                }
            }
        }
    }

    private func tile(_ unlock: PaywallUnlock, lit: Bool) -> some View {
        VStack(spacing: 7) {
            Circle()
                .fill(lit ? OB.brass : .clear)
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(lit ? .clear : OB.line, lineWidth: 1))
                .overlay(
                    Image(systemName: unlock.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(lit ? OB.onBrass : OB.text)
                )
                .shadow(color: lit ? OB.brass.opacity(0.28) : .clear, radius: 9)

            Text(l10n[unlock.titleKey])
                .font(OB.ui(11.5, weight: lit ? 600 : 400))
                .foregroundStyle(lit ? OB.text : OB.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bottom: some View {
        VStack(spacing: 10) {
            if plans.isEmpty {
                // Магазин ещё не ответил. Показываем ожидание, а не выдуманные
                // цены: цифра, за которую нельзя купить, хуже её отсутствия.
                ProgressView()
                    .tint(OB.brass)
                    .frame(height: 92)
            } else {
                HStack(spacing: 8) {
                    ForEach(plans) { card($0) }
                }
                .padding(.top, 12)
            }

            Button(action: buy) {
                ZStack {
                    Text(callToAction).opacity(store?.isPurchasing == true ? 0 : 1)
                    if store?.isPurchasing == true {
                        ProgressView().tint(OB.onBrass)
                    }
                }
            }
            .buttonStyle(OBButton())
            .disabled(plan == nil || store?.isPurchasing == true)
            .opacity(plan == nil ? 0.5 : 1)

            // Строка под кнопкой есть всегда и всегда занимает две строки.
            // Раньше она появлялась только у годового, с бесплатной неделей, —
            // блок кнопок становился выше, распорки сдвигали сетку и заголовок,
            // и весь экран прыгал при переключении тарифа. Место под неё
            // держится независимо от того, что в ней написано.
            Text(plan?.hasTrial == true
                 ? l10n(.pwAfterTrial, plan?.priceWithPeriod(l10n) ?? "")
                 : l10n[.pwCancelAnytime])
                .font(OB.ui(11.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(OB.textFaint)
                .lineLimit(2, reservesSpace: true)

            if let error = store?.lastError {
                Text(error)
                    .font(OB.ui(11.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0xE07C72))
            }

            HStack(spacing: 18) {
                Button(l10n[.pwRestore], action: restore)
                    .buttonStyle(.plain)
                Button(l10n[.notNow]) { dismiss() }
                    .buttonStyle(.plain)
            }
            .font(OB.ui(13, weight: 500))
            .foregroundStyle(OB.textMuted)
            .padding(.top, 4)

            // Условия и политика обязаны быть на самом экране оплаты, а не
            // только в описании в App Store: правило 3.1.2 требует их в обоих
            // местах, и из-за отсутствия ссылки в описании ревью уже отклонило
            // первую подачу. Строка мельче и бледнее кнопок — читать её не
            // зовут, но найти можно, не уходя с экрана. Подчёркнуты, потому что
            // при такой светлоте ничто другое не выдаёт в них ссылки.
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
    }

    /// Надпись на кнопке зависит от тарифа: с бесплатным периодом зовём начать
    /// его (срок свой у каждого тарифа), без него — честно говорим цену, а не
    /// прячем её под «Продолжить».
    private var callToAction: String {
        guard let plan else { return l10n[.continueAction] }
        return plan.callToAction(l10n)
    }

    /// Карточка тарифа. Выбранный обведён латунью — как в макете.
    private func card(_ plan: PaywallPlan) -> some View {
        let isOn = plan.period == selected
        return Button { selected = plan.period } label: {
            VStack(spacing: 4) {
                Text(l10n[plan.nameKey])
                    .font(OB.ui(13.5, weight: 600))
                    .foregroundStyle(isOn ? OB.text : OB.textMuted)
                Text(plan.price)
                    .font(OB.ui(17, weight: 600))
                    .foregroundStyle(OB.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(plan.note(l10n))
                    .font(OB.ui(10.5, weight: plan.hasTrial ? 600 : 400))
                    .foregroundStyle(plan.hasTrial ? OB.brass : OB.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isOn ? OB.brass.opacity(0.08) : OB.raised))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isOn ? OB.brass : OB.line, lineWidth: isOn ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func buy() {
        guard let store, let plan else { return }
        Task { await store.purchase(plan) }
    }

    private func restore() {
        guard let store else { return }
        Task { await store.restorePurchases() }
    }
}

/// Что пейволл говорит над сеткой: надпись, плашки, заголовок, подзаголовок,
/// порядок плиток — и имя варианта для `paywall_view`.
///
/// С замка — «Твой выбор» с тем, что тапнули. Иначе — ветка онбординга, в
/// том числе позже, с «Вида» или «Мест»: человек отвечал один раз, и экран
/// помнит его слова. Ни того ни другого — общий заголовок.
struct PaywallPitch {
    struct Chip: Hashable {
        var symbol: String? = nil
        let text: String
    }

    let eyebrow: String?
    let chips: [Chip]
    let title: String
    let sub: String
    let unlocks: [PaywallUnlock]
    let variant: String

    @MainActor
    init(source: PaywallSource, picks: [PaywallPick], settings: AppSettings, l10n: L10n) {
        let pickChips = picks.map { Chip(symbol: $0.unlock.symbol, text: $0.name) }

        if source != .onboarding, let first = picks.first {
            eyebrow = l10n[.pwPickedEyebrow]
            chips = pickChips
            title = l10n[.pwTitle]
            sub = l10n[.pwSub]
            unlocks = [first.unlock] + PaywallUnlock.allCases.filter { $0 != first.unlock }
            variant = "pick"
            return
        }

        guard let goal = settings.goal else {
            eyebrow = nil
            chips = []
            title = l10n[.pwTitleGeneric]
            sub = l10n[.pwSub]
            unlocks = PaywallUnlock.allCases
            variant = "generic"
            return
        }

        unlocks = goal.unlocks
        variant = goal.rawValue
        switch goal {
        case .comfort:
            eyebrow = l10n[.pwComfortEyebrow]
            // Не больше четырёх: дальше плашки съедают место заголовка.
            chips = settings.themes.sorted().prefix(4).map { Chip(text: l10n.theme($0)) }
            title = l10n[.pwComfortTitle]
            sub = l10n[.pwComfortSub]
        case .daily:
            let time = ClockTime.text(minutes: settings.dailyVerseMinutes, locale: l10n.locale)
            eyebrow = l10n(.pwDailyEyebrow, time).uppercased()
            chips = [Chip(text: l10n[.chipDailyVerse]), Chip(text: l10n[.surfaceLock])]
            title = l10n[.pwDailyTitle]
            sub = l10n[.pwDailySub]
        case .feed:
            eyebrow = l10n[.pwFeedEyebrow]
            chips = [Chip(text: l10n[.pauseTitle])]
            title = l10n[.pwFeedTitle]
            sub = l10n[.pwFeedSub]
        case .beauty:
            // Число шрифтов и иконок считается, а не пишется в строку: стоит
            // добавить иконку — и подзаголовок соврал бы.
            let fonts = l10n.count(VerseFont.allCases.filter(\.isPremium).count, .fontsUnit)
            let icons = l10n.count(AppIcon.allCases.filter(\.isPremium).count, .iconsUnit)
            eyebrow = picks.isEmpty ? nil : l10n[.pwPickedEyebrow]
            chips = pickChips
            title = l10n[.pwBeautyTitle]
            sub = l10n(picks.isEmpty ? .pwBeautySubNoPick : .pwBeautySub, fonts, icons)
        }
    }
}
