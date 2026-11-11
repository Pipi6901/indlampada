import DeepamCore
import SwiftUI

/// Выбор шрифта.
///
/// Раньше шрифт перебирался по кругу нажатием на строку настроек. Пока
/// вариантов было три, это сходило с рук; с девятью — нет, и дело даже не в
/// числе нажатий: шрифт меняет весь интерфейс, поэтому строка, по которой
/// нажимают, съезжает под пальцем вместе со всем остальным. Отдельный лист
/// разводит выбор и результат: список показывает начертания рядом, а экран под
/// ним перерисовывается один раз.
struct FontSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore
    /// Область, для которой выбирают: шрифт по-областной.
    let area: AppearanceArea
    /// Строка настоящего стиха для образца. Названия шрифтов латинские, а
    /// приложение читают на пяти языках — по «Literata» не увидеть, как
    /// начертание держит кириллицу или диакритику.
    let sample: String

    @State private var showsPaywall = false
    @State private var paywallPick: PaywallPick?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n[.font])
                .font(theme.display(24))
                .foregroundStyle(theme.text)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(VerseFont.allCases) { face in
                        row(face)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
        .sheet(isPresented: $showsPaywall) {
            PaywallSheet(settings: settings, entitlements: entitlements, source: .font, pick: paywallPick)
        }
    }

    private func row(_ face: VerseFont) -> some View {
        let unlocked = entitlements.isUnlocked(face)
        return Button {
            guard unlocked else {
                paywallPick = PaywallPick(.fonts, name: face.title)
                showsPaywall = true
                return
            }
            settings.setFont(face, for: area)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(face == .system ? l10n[.systemFont] : face.title)
                        .font(Fonts.font(face, size: 17, weight: 500))
                        .foregroundStyle(theme.text)
                    Text(sample)
                        .font(Fonts.font(face, size: 13, weight: 400))
                        .foregroundStyle(theme.textFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                // Замок вместо галочки, а не рядом с ней: закрытое начертание
                // выбранным быть не может, и два знака в одной строке никогда
                // не встретятся.
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textFaint)
                } else if settings.font(for: area) == face {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(14)
            // Высота строки фиксированная: у начертаний разная собственная
            // высота, и без этого список менял бы длину при каждом выборе.
            .frame(height: 62)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.raised))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel((face == .system ? l10n[.systemFont] : face.title)
                            + (unlocked ? "" : ", " + l10n[.subscribe]))
    }
}
