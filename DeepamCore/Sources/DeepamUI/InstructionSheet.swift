import DeepamCore
import SwiftUI

/// Шторка «Как поставить» — макет 10.
///
/// Заголовок, три пронумерованных шага с подсказками и приписка о том, что
/// будет дальше. У двух поверхностей сверху ещё и схема пути: текст работает
/// для того, кто уже делал это раньше и узнаёт названия пунктов, а тому, кто
/// не делал ни разу, надо увидеть, куда девается палец.
///
/// Схема и список идут вместе, а не вместо друг друга. Картинка показывает
/// куда, текст — как именно называется пункт, по которому человек сверяется с
/// живым экраном в руке. Номер текущей фазы подсвечивает свой шаг в списке,
/// поэтому они не расходятся.
struct InstructionSheet: View {
    @Environment(\.theme) private var theme
    let surface: Surface
    /// Вызывается, когда человек подтвердил, что поставил.
    let onDone: () -> Void

    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Текущая фаза схемы. Крутится сама: человек держит телефон в другой руке
    /// и листать третьей ему нечем.
    @State private var phase = 0

    private var hasAnimation: Bool { HowToAnimation.exists(for: surface) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l10n[surface.instructionTitleKey])
                .font(theme.display(24))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 22)

            if hasAnimation {
                HowToAnimation(surface: surface, phase: phase)
                    .padding(.bottom, 22)
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(surface.steps.enumerated()), id: \.element.id) { index, step in
                    row(index + 1, step, isLit: hasAnimation && index == phase)
                }
            }

            Text(l10n[surface.installNoteKey])
                .font(theme.ui(12))
                .foregroundStyle(theme.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
                .padding(.bottom, 24)

            actions
        }
        .padding(.horizontal, 26)
        .padding(.top, 24)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fittedSheet()
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
        .task {
            guard hasAnimation else { return }
            let count = max(1, surface.steps.count)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.35)) { phase = (phase + 1) % count }
            }
        }
    }

    /// Кнопки идут в том порядке, в каком человек их нажимает.
    ///
    /// Готовая команда ставится первой и одним тапом; «Команды» открываются
    /// вторыми, потому что автоматизацию всё равно придётся собрать руками —
    /// программно её создать нельзя, такого API у Apple нет. Прятать второй шаг
    /// за первым значило бы обещать, что всё сделается само.
    @ViewBuilder
    private var actions: some View {
        if let install = surface.shortcutURL {
            Button(l10n[.installShortcut]) { openURL(install) }
                .buttonStyle(PrimaryButton())
                .padding(.bottom, 10)

            if let destination = surface.systemAppURL {
                Button(l10n[.openShortcuts]) { openURL(destination) }
                    .buttonStyle(GhostButton())
                    .padding(.bottom, 14)
            }

            Button(l10n[.markDone]) {
                onDone()
                dismiss()
            }
            .font(theme.ui(14, weight: 500))
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        } else {
            if let destination = surface.systemAppURL {
                Button(l10n[surface == .pauseBeforeFeed ? .openShortcuts : .openSettings]) {
                    openURL(destination)
                }
                .buttonStyle(PrimaryButton())
                .padding(.bottom, 10)
            }

            Button(surface.opensSystemApp ? l10n[.markDone] : l10n[.close]) {
                if surface.opensSystemApp { onDone() }
                dismiss()
            }
            .buttonStyle(GhostButton())
        }
    }

    /// Шаг: номер в кружке, под ним заголовок и подсказка.
    ///
    /// Подсказка подтверждает, что человек попал куда надо, — без неё
    /// незнакомый системный экран заставляет бросить на середине.
    private func row(_ number: Int, _ step: Surface.Step, isLit: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(theme.ui(12, weight: isLit ? 600 : 500))
                .foregroundStyle(isLit ? theme.buttonText : theme.textMuted)
                .frame(width: 26, height: 26)
                .background(Circle().fill(isLit ? theme.accent : theme.raised))

            VStack(alignment: .leading, spacing: 3) {
                Text(l10n[step.titleKey])
                    .font(theme.ui(15, weight: 500))
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l10n[step.hintKey])
                    .font(theme.ui(12))
                    .foregroundStyle(theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(isLit || !hasAnimation ? 1 : 0.55)
    }
}
