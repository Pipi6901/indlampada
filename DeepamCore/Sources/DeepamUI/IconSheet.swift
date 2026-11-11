import DeepamCore
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Выбор иконки приложения.
///
/// Система при каждой смене показывает своё окно «Вы изменили иконку». Это
/// поведение iOS, отключить его нельзя.
struct IconSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore

    @State private var showsPaywall = false
    @State private var paywallPick: PaywallPick?

    /// Три в ряд, а не две. При двух плитка выходила почти в полэкрана: семь
    /// вариантов складывались в четыре ряда, лист с фиксированной высотой их не
    /// вмещал, и нижние обрезались вместе с подписями.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var current: AppIcon { AppIcon(rawValue: settings.appIcon) ?? .default }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n[.appIconTitle])
                .font(theme.display(24))
                .foregroundStyle(theme.text)

            // Прокрутка обязательна: высота листа фиксированная, и стоит
            // добавить восьмую иконку — ряд снова уехал бы за нижний край.
            // Со скроллом список переживает любое их число.
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AppIcon.allCases) { icon in
                        tile(icon)
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
        .sheet(isPresented: $showsPaywall) {
            PaywallSheet(settings: settings, entitlements: entitlements, source: .icon, pick: paywallPick)
        }
    }

    private func tile(_ icon: AppIcon) -> some View {
        let unlocked = entitlements.isUnlocked(icon)
        let isSelected = current == icon
        return Button {
            guard unlocked else {
                paywallPick = PaywallPick(.icons, name: l10n[icon.titleKey])
                showsPaywall = true
                return
            }
            settings.appIcon = icon.rawValue
            AppIconSwitcher.apply(icon)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                IconSwatch(icon: icon, isLocked: !unlocked)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2)
                    )
                Text(l10n[icon.titleKey])
                    .font(theme.ui(11))
                    .foregroundStyle(isSelected ? theme.text : theme.textFaint)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n[icon.titleKey] + (unlocked ? "" : ", " + l10n[.subscribe]))
    }
}

/// Плитка иконки — здесь и на шаге иконки в онбординге.
///
/// У картиночных вариантов показывает саму картинку из ресурсов пакета, у
/// остальных повторяет рецепт настоящей иконки — градиент и лампу поверх.
struct IconSwatch: View {
    let icon: AppIcon
    let isLocked: Bool
    /// В онбординге плитки мельче — четыре в ряд — и скругление меньше.
    var cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(background)
            .aspectRatio(1, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 6)
                }
            }
    }
}

private extension IconSwatch {
    var background: LinearGradient {
        let swatch = icon.swatch
        return LinearGradient(colors: [Color(hex: swatch.top), Color(hex: swatch.bottom)],
                              startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    var content: some View {
        if let asset = icon.previewAsset {
            Image(asset, bundle: .module)
                .resizable()
                .scaledToFill()
                .opacity(isLocked ? 0.35 : 1)
        } else {
            Image("hero", bundle: .module)
                .resizable()
                .scaledToFit()
                .padding(12)
                .colorMultiply(icon.swatch.lamp.map { Color(hex: $0) } ?? .white)
                .opacity(isLocked ? 0.35 : 1)
        }
    }
}

/// Смена иконки в системе.
///
/// Настройка и система должны сойтись: `AppSettings` помнит выбор, но саму
/// иконку меняет только `UIApplication`, и сделать это можно лишь из
/// приложения — виджету и расширениям такой возможности не дано. Отсюда
/// отдельный тип: в `DeepamUI` заходит и watchOS, где `UIApplication` нет.
enum AppIconSwitcher {
    @MainActor
    static func apply(_ icon: AppIcon) {
        #if os(iOS)
        let application = UIApplication.shared
        guard application.supportsAlternateIcons,
              application.alternateIconName != icon.alternateName else { return }
        // Ошибку глотаем осознанно: единственная её причина — иконки нет в
        // бандле, то есть сборка собрана неправильно. Показывать это человеку
        // нечем и незачем, а система и так покажет своё окно при успехе.
        application.setAlternateIconName(icon.alternateName) { _ in }
        #endif
    }
}
