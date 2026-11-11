import DeepamCore
import SwiftUI

/// Сегментный переключатель из макета: капсула с внутренними капсулами.
///
/// Один компонент на все случаи — область на «Виде», размер виджета, длина
/// стиха, шрифт, выравнивание, формат на «Поделиться». В макете они выглядят
/// одинаково, значит и в коде это одно место.
struct Segmented<Item: Hashable & Identifiable>: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Item
    let items: [Item]
    let title: (Item) -> String

    @Environment(\.l10n) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                segment(item)
            }
        }
        .padding(4)
        .background(Capsule().fill(theme.raised))
    }

    private func segment(_ item: Item) -> some View {
        let isSelected = selection == item
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { selection = item }
        } label: {
            Text(title(item))
                .font(theme.ui(12, weight: isSelected ? 500 : 400))
                .foregroundStyle(isSelected ? theme.buttonText : theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background { if isSelected { Capsule().fill(theme.buttonFill) } }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Строка со значением и шевроном: «Шрифт — Literata ›».
struct DisclosureRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(theme.ui(14))
                    .foregroundStyle(theme.textMuted)
                Spacer()
                Text(value)
                    .font(theme.ui(13, weight: 500))
                    .foregroundStyle(theme.text)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Capsule().fill(theme.raised))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Выбор языка и перевода. Открывается со строки на экране «Вид».
struct LanguageSheet: View {
    @Environment(\.theme) private var theme
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n[.languageAndEdition])
                .font(theme.display(24))
                .foregroundStyle(theme.text)

            VStack(spacing: 8) {
                ForEach(AppLocale.allCases) { locale in
                    Button {
                        settings.language = locale
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locale.nativeName)
                                    .font(theme.ui(15, weight: 500))
                                    .foregroundStyle(theme.text)
                                Text(locale.editionName)
                                    .font(theme.ui(12))
                                    .foregroundStyle(theme.textFaint)
                                if let credit = locale.editionCredit {
                                    Text(credit)
                                        .font(theme.ui(10.5))
                                        .foregroundStyle(theme.textFaint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                            if (settings.language ?? .detect()) == locale {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.raised))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Источник текста: книга, переводчик, оцифровка. Срок защиты истёк, но указать
            // источник нужно, чтобы текст можно было сверить.
            VStack(alignment: .leading, spacing: 6) {
                Text(Legal.sourceNotice)
                    .font(theme.ui(10))
                    .foregroundStyle(theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Wikisource", destination: Legal.sourceURL)
                    .font(theme.ui(10, weight: 600))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fittedSheet()
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.sheetFill)
    }
}
