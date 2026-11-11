import DeepamCore
import SwiftUI

/// Шторка с контекстом отрывка — макет 08.
///
/// Кто говорит и при каких обстоятельствах. Не толкование и не проповедь —
/// одна строка обстановки, поэтому шторка маленькая.
struct ContextSheet: View {
    @Environment(\.theme) private var theme
    let card: Card
    let context: String?

    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReferenceLabel(reference: l10n[.context])
                .padding(.bottom, 18)

            // Прокрутки здесь больше нет. Она растягивалась на весь остаток
            // шторки фиксированной высоты, и между подписью и кнопкой зияла
            // пустота в треть экрана. Строки контекста ограничены 34 словами на
            // сборке корпуса, так что содержимое заведомо помещается.
            VStack(alignment: .leading, spacing: 16) {
                if let context {
                    Text(context)
                        .font(theme.display(18))
                        .foregroundStyle(theme.text)
                        .lineSpacing(theme.spacing(18, lineHeight: 1.905))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(card.reference)
                    .font(theme.ui(11))
                    .foregroundStyle(theme.textFaint)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(l10n[.understood]) { dismiss() }
                .buttonStyle(GhostButton())
                .padding(.top, 18)
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fittedSheet()
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
    }
}
