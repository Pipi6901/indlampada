import DeepamCore
import SwiftUI

/// Экран «Сегодня» — макеты 07, 07a, 07b.
///
/// Колонка содержимого распределена `space_between`: дата вверху, стих в
/// середине, кнопки внизу. Три состояния макета отличаются только кнопками:
/// пока есть непоставленные места, главная кнопка зовёт поставить следующее,
/// а «Поделиться» уходит во второстепенную; когда поставлено всё — «Поделиться»
/// становится главной и остаётся одна.
public struct TodayScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @State private var model: TodayModel
    @Bindable private var settings: AppSettings
    private let entitlements: any EntitlementStore
    /// Тур: шаг со свайпом закрывается тем, что человек пролистнул.
    private let coach: Coach?

    @State private var showsContext = false
    @State private var showsShare = false
    @State private var instruction: Surface?
    @State private var direction: Edge = .top

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let date: Date

    public init(corpus: Corpus,
                settings: AppSettings,
                entitlements: any EntitlementStore,
                coach: Coach? = nil,
                date: Date = .now) {
        self.date = date
        self.settings = settings
        self.entitlements = entitlements
        self.coach = coach
        let model = TodayModel(corpus: corpus, day: VerseEngine.dayIndex(for: date))
        model.themes = settings.themes
        _model = State(initialValue: model)
    }

    public var body: some View {
        // Прокрутки здесь быть не может: вертикальный свайп листает стихи. Если
        // колонка не влезает в высоту — длинный стих на внешнем экране iPhone
        // Duo, где под неё с таб-баром остаётся около 540 точек, или на iPhone
        // SE, — стих ступенькой мельче. Берётся первая ступень, при которой
        // колонка помещается; на обычных iPhone это почти всегда исходный кегль
        // (проверено расчётом по всему корпусу: на iPhone 15 из 288 стихов 239
        // идут целиком, остальные — на ступень или две мельче).
        //
        // Если оригинал с переводом не влезают даже мелко (самые длинные стихи на
        // маленьком экране), оригинал на «Сегодня» уступает место: перевод
        // читается лучше, чем два текста по девять точек. В виджетах, на
        // карточке для шеринга и в уведомлении он остаётся.
        ViewThatFits(in: .vertical) {
            column(scale: 1)
            column(scale: 0.86)
            column(scale: 0.74)
            column(scale: 1, dropsOriginal: true)
            column(scale: 0.86, dropsOriginal: true)
            column(scale: 0.74, dropsOriginal: true)
            column(scale: 0.64, dropsOriginal: true)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .gesture(swipe)
        .sheet(isPresented: $showsContext) {
            ContextSheet(card: model.card, context: model.context)
        }
        .sheet(isPresented: $showsShare) {
            ShareScreen(card: model.card, settings: settings, entitlements: entitlements)
        }
        .sheet(item: $instruction) { surface in
            InstructionSheet(surface: surface) { settings.markInstalled(surface) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh(day: VerseEngine.dayIndex(for: .now))
            }
        }
        .onChange(of: settings.themes) { _, themes in
            model.themes = themes
        }
    }

    /// Колонка экрана: дата вверху, стих в середине, кнопки внизу.
    private func column(scale: CGFloat, dropsOriginal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dateLine
            Spacer(minLength: 12)
            verse(scale: scale, dropsOriginal: dropsOriginal)
            Spacer(minLength: 12)
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Дата

    /// Слева вверху, строчными: «вторник, 3 сентября».
    ///
    /// При листании превращается в возврат к стиху дня — иначе пролиставший
    /// десяток стихов не поймёт, что смотрит уже не сегодняшнее.
    private var dateLine: some View {
        Group {
            if model.isBrowsing {
                Button {
                    withAnimation(motion) { model.returnToDaily() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .medium))
                        Text(l10n[.backToDaily])
                            .font(theme.ui(13))
                    }
                    .foregroundStyle(theme.accent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(l10n(.depthHint, model.depth))
            } else {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(theme.ui(13))
                    .foregroundStyle(theme.textFaint)
            }
        }
        .frame(height: 20, alignment: .leading)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: model.isBrowsing)
    }

    // MARK: - Стих

    private func verse(scale: CGFloat, dropsOriginal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ReferenceLabel(reference: model.card.reference,
                           edition: language.editionShort)
                .padding(.bottom, 18)

            // Оригинал на санскрите над переводом; у основного текста —
            // один оригинал. Кегли подбираются по длине стиха.
            VerseText(parts: dropsOriginal ? withoutOriginal : parts, scale: scale)
                .id(model.card.id)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: direction == .top ? .bottom : .top)
                                .combined(with: .opacity),
                            removal: .move(edge: direction).combined(with: .opacity)
                        )
                )

            ContextPill { showsContext = true }
                .padding(.top, 20)
                .opacity(model.context == nil ? 0 : 1)
                .disabled(model.context == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Тур подсвечивает стих целиком: свайп работает на всём экране, но
        // показать, ЧТО листается, можно только на самом стихе.
        .coachAnchor(.swipe)
    }

    private var language: AppLocale { settings.language ?? .detect() }

    /// Что показываем: оригинал, перевод или оба. Кегль от длины стиха выбирает
    /// сам `VerseText`: пул неоднородный, от пяти слов до абзаца.
    private var parts: VerseParts {
        model.card.parts(locale: language, showsOriginal: settings.showsOriginal)
    }

    /// Один перевод — запасная ступень для длинных стихов. У санскритского
    /// интерфейса перевода нет, и оригинал убирать не из чего: остаётся как есть.
    private var withoutOriginal: VerseParts {
        parts.translation == nil ? parts : VerseParts(original: nil, translation: parts.translation)
    }

    // MARK: - Кнопки

    private var actions: some View {
        VStack(spacing: 12) {
            if let next = settings.nextSurface {
                Button(l10n[next.callToActionKey]) {
                    if entitlements.isUnlocked(next) { instruction = next }
                }
                .buttonStyle(PrimaryButton())

                Button(l10n[.share]) { showsShare = true }
                    .buttonStyle(GhostButton())
            } else {
                Button(l10n[.share]) { showsShare = true }
                    .buttonStyle(PrimaryButton())
            }
        }
        .padding(.bottom, 8)
    }

    /// Порог в 44 точки — примерно палец. Меньше даёт ложные срабатывания при
    /// обычном касании, больше требует размашистого движения.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                guard abs(value.translation.height) > 44 else { return }
                let up = value.translation.height < 0
                direction = up ? .top : .bottom
                withAnimation(motion) {
                    if up { model.showNext() } else { model.showPrevious() }
                    coach?.completed(.swipe)
                }
            }
    }

    private var motion: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.26)
    }
}
