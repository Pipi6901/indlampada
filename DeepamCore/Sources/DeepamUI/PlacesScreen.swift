import DeepamCore
import SwiftUI

/// Экран «Места» — макет 09.
///
/// Заголовок со счётчиком и полосой прогресса, дальше два раздела: сетка плиток
/// «На экранах» и одна широкая строка «В моменте». Тумблер здесь отмечает, а не
/// включает: поставить виджет за человека приложение не может, это делает
/// система. Поэтому тап по плитке открывает инструкцию.
struct PlacesScreen: View {
    @Environment(\.theme) private var theme
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    /// Тур ждёт, что человек откроет инструкцию и отметит поверхность.
    var coach: Coach? = nil

    @Environment(\.l10n) private var l10n
    @State private var instruction: Surface?
    @State private var paywallFor: Surface?

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                section(.screens) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Surface.all(in: .screens)) { tile($0) }
                    }
                }

                section(.moment) {
                    ForEach(Surface.all(in: .moment)) { wideRow($0) }
                    DailyVerseRow(settings: settings)
                    PromoRow(settings: settings)
                }
            }
            .padding(.horizontal, 26)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .scrollFade()
        .sheet(item: $instruction) { surface in
            InstructionSheet(surface: surface) {
                settings.markInstalled(surface)
                // «Отметить» в шторке — то же, что переключатель на плитке.
                coach?.completed(.markDone)
            }
        }
        .sheet(item: $paywallFor) { surface in
            PaywallSheet(settings: settings, entitlements: entitlements, source: .places,
                         pick: surface == .wallpaper
                            ? PaywallPick(.wallpaper, name: l10n.name(surface))
                            : PaywallPick(.standBy, name: l10n.name(surface)))
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n[.placesTitle])
                .font(theme.display(30))
                .foregroundStyle(theme.text)

            Text(l10n(.placesProgress, installed, total))
                .font(theme.ui(13))
                .foregroundStyle(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            progress
        }
    }

    private var installed: Int { settings.enabledSurfaces.count }
    private var total: Int { Surface.shipped.count }

    /// Полоса прогресса: заполненная часть — сколько мест уже стоит.
    private var progress: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: geometry.size.width * CGFloat(installed) / CGFloat(total))
            }
        }
        .frame(height: 3)
        .padding(.top, 2)
    }

    /// Название раздела берётся из таблицы строк, а не из модели: модель
    /// языка интерфейса не знает и знать не должна.
    private func groupTitle(_ group: Surface.Group) -> String {
        switch group {
        case .screens: l10n[.groupScreens]
        case .moment: l10n[.groupMoment]
        }
    }

    private func section<Content: View>(_ group: Surface.Group,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(groupTitle(group).uppercased())
                .font(theme.ui(10, weight: 600))
                .spaced(1.2)
                .foregroundStyle(theme.textFaint)
            content()
        }
    }

    // MARK: - Плитка

    private func tile(_ surface: Surface) -> some View {
        let unlocked = entitlements.isUnlocked(surface) && surface.isAvailable
        let isOn = settings.enabledSurfaces.contains(surface)

        return Button {
            if unlocked || !surface.isAvailable {
                instruction = surface
                coach?.completed(.places)
            }
            else { paywallFor = surface }
        } label: {
            VStack(spacing: 10) {
                SurfacePreview(surface: surface)
                    .overlay(alignment: .topTrailing) {
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.chromeInk)
                                .padding(5)
                                .background(Circle().fill(.black.opacity(0.45)))
                                .padding(6)
                        }
                    }

                HStack(spacing: 6) {
                    Text(l10n.name(surface))
                        .font(theme.ui(12))
                        .foregroundStyle(isOn ? theme.text : theme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    toggle(surface, isOn: isOn, enabled: unlocked)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.raised)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        // Оба шага тура показывают на первую плитку: сперва по ней открывают
        // инструкцию, потом её же переключателем отмечают готовность. Метка
        // только на ней — на всех подряд её забрала бы последняя отрисованная.
        .coachAnchors(surface == Surface.all(in: .screens).first ? [.places, .markDone] : [])
    }

    /// Широкая строка раздела «В моменте».
    private func wideRow(_ surface: Surface) -> some View {
        let unlocked = entitlements.isUnlocked(surface)
        let isOn = settings.enabledSurfaces.contains(surface)

        return Button {
            if unlocked {
                instruction = surface
                // Инструкцию открыли не по подсвеченной плитке, а по этой
                // строке — сделано то же самое, шаг засчитывается.
                coach?.completed(.places)
            } else {
                paywallFor = surface
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(theme.chrome)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "hand.raised")
                            .font(.system(size: 15))
                            .foregroundStyle(theme.chromeInk)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.name(surface))
                        .font(theme.ui(14, weight: 500))
                        .foregroundStyle(isOn ? theme.text : theme.textMuted)
                    if let subtitle = surface.subtitleKey.map({ l10n[$0] }) {
                        Text(subtitle)
                            .font(theme.ui(11))
                            .foregroundStyle(theme.textFaint)
                    }
                }

                Spacer(minLength: 0)
                toggle(surface, isOn: isOn, enabled: unlocked)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.raised)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ surface: Surface, isOn: Bool, enabled: Bool) -> some View {
        Toggle("", isOn: Binding(
            get: { isOn },
            set: {
                $0 ? settings.markInstalled(surface) : settings.markRemoved(surface)
                coach?.completed(.markDone)
            }
        ))
        .labelsHidden()
        .scaleEffect(0.75)
        .frame(width: 38, height: 22)
        .tint(theme.accent)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(l10n.name(surface))
    }
}
