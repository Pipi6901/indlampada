import DeepamCore
import SwiftUI

/// Лист «подписка закончилась».
///
/// Без него человек открыл бы приложение и увидел, что фон, шрифт и иконка
/// сменились сами, — и решил бы, что приложение сломалось. Здесь сказано, что
/// случилось, и предложено вернуть платное. Показывается, только когда откат
/// действительно что-то снял: у того, кто платным не пользовался, сообщать
/// нечего.
struct ProExpiredSheet: View {
    let onUpgrade: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l10n[.proEndedTitle])
                .font(theme.display(24))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(l10n[.proEndedBody])
                .font(theme.ui(15))
                .foregroundStyle(theme.textMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)

            VStack(spacing: 10) {
                Button(l10n[.proEndedCta], action: onUpgrade)
                    .buttonStyle(PrimaryButton())
                Button(l10n[.notNow]) { dismiss() }
                    .buttonStyle(GhostButton())
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fittedSheet()
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
    }
}
