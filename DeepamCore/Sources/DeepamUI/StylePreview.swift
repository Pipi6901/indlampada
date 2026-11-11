import DeepamCore
import SwiftUI

/// Заливка набора: у большинства это градиент из двух цветов палитры.
extension VerseStyle {
    var fill: LinearGradient {
        LinearGradient(colors: [Color(hex: palette.background), Color(hex: palette.second)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var textColor: Color { Color(hex: palette.text) }
    var accentColor: Color { Color(hex: palette.accent) }
}

/// Квадратная плитка набора с «Aa» — как в макете.
struct StyleSwatch: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let style: VerseStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(style.fill)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(style.textColor.opacity(0.7))
                    } else {
                        Text("Aa")
                            .font(theme.display(19))
                            .foregroundStyle(style.textColor)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? theme.accent : .clear,
                                      lineWidth: 2)
                )

            Text(l10n[style.titleKey])
                .font(theme.ui(10))
                .foregroundStyle(isSelected ? theme.text : theme.textFaint)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

/// Плитка фона-изображения. Форма та же, что у цветной, — это один и тот же
/// выбор, просто сделанный картинкой.
struct SceneSwatch: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let scene: VerseScene
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.clear)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image("\(scene.asset)-square", bundle: .module)
                        .resizable()
                        .scaledToFill()
                }
                .overlay {
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 4)
                    } else {
                        Text("Aa")
                            .font(theme.display(19))
                            .foregroundStyle(scene.prefersLightText ? .white : .black)
                            .shadow(color: (scene.prefersLightText ? Color.black : .white).opacity(0.5),
                                    radius: 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2)
                )

            Text(l10n[scene.titleKey])
                .font(theme.ui(10))
                .foregroundStyle(isSelected ? theme.text : theme.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
    }
}

/// Предпросмотр стиха в выбранном наборе — то, что человек настраивает.
///
/// Разный для каждой области: в приложении это карточка со ссылкой сверху,
/// в виджете ссылка уходит вниз мелким кеглем, а на экране блокировки поверх
/// всего лежат часы и дата, потому что там стих живёт под ними.
struct AppearancePreview: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let area: AppearanceArea
    let style: VerseStyle
    /// Выбранный фон-изображение. Без него предпросмотр показывал бы цветной
    /// набор даже тогда, когда виджет уже рисуется картинкой.
    var scene: VerseScene? = nil
    let font: VerseFont
    let text: String
    let reference: String
    var size: WidgetSize = .medium
    var alignment: VerseAlignment = .leading
    var length: VerseLength = .full

    var body: some View {
        switch area {
        case .app: appCard
        case .widgets: widgetCard
        case .lockScreen: lockCard
        }
    }

    private var appCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReferenceLabel(reference: reference, edition: "", tint: tint)
            Text(text)
                .font(verseFont(19))
                .foregroundStyle(ink)
                .lineSpacing(verseSpacing(19, lineHeight: 1.825))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill(.tall))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Предпросмотр виджета в пропорциях выбранного размера.
    ///
    /// Раньше карточка была одной высоты для всех размеров и от переключателя
    /// менялся только кегль — то есть предпросмотр показывал не то, что человек
    /// выбрал. Теперь он держит настоящее соотношение сторон, и «малый» виден
    /// квадратным, а «средний» вытянутым.
    private var widgetCard: some View {
        VStack(alignment: alignment == .center ? .center : .leading,
               spacing: size == .small ? 6 : 10) {
            Spacer(minLength: 0)
            Text(text)
                .font(verseFont(size == .small ? 11 : 16))
                .foregroundStyle(ink)
                .lineSpacing(verseSpacing(size == .small ? 11 : 16, lineHeight: 1.785))
                .lineLimit(size == .small ? 4 : nil)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: size != .small)
            Text(reference.uppercased())
                .font(theme.ui(8, weight: 600))
                .spaced(0.8)
                .foregroundStyle(tint)
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .padding(size == .small ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: alignment == .center ? .center : .leading)
        // Широкий виджет берёт горизонтальную версию, остальные квадратную —
        // так же, как настоящий виджет.
        .background(fill(size == .medium || size == .standBy ? .wide : .square))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .aspectRatio(size.aspectRatio, contentMode: .fit)
        // Малый и большой во всю ширину экрана не тянутся: раздутый квадрат
        // выглядит не как виджет, а как карточка.
        .frame(maxWidth: narrow ? 190 : nil, alignment: .leading)
    }

    /// Квадратным размерам ширину ограничиваем, вытянутым — нет.
    private var narrow: Bool { size == .small || size == .large }

    @ViewBuilder
    private func fill(_ variant: SceneBackground.Variant) -> some View {
        if let scene {
            SceneBackground(scene: scene, variant: variant)
        } else {
            style.fill
        }
    }

    /// Цвета текста берутся у картинки, когда она выбрана.
    private var ink: Color { scene.map { Color(hex: $0.palette.text) } ?? style.textColor }
    private var tint: Color { scene.map { Color(hex: $0.palette.accent) } ?? style.accentColor }

    /// Экран блокировки: сверху дата и часы системным начертанием, под ними
    /// область виджета. Цвет здесь задаёт iOS, поэтому фон превью нейтральный.
    private var lockCard: some View {
        VStack(spacing: 6) {
            Text(l10n.mockDate)
                .font(theme.ui(11))
                .foregroundStyle(.white.opacity(0.7))
            Text("9:41")
                .font(.system(size: 46, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Text(length == .short ? String(text.prefix(48)) + "…" : text)
                .font(verseFont(12))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .frame(maxWidth: .infinity,
                       alignment: alignment == .center ? .center : .leading)
                .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x3F2F4B), Color(hex: 0x1C1521)],
                                     startPoint: .top, endPoint: .bottom))
        )
    }

    /// Шрифт берётся из параметра, а не из оформления: предпросмотр показывает
    /// именно то начертание, которое настраивают.
    ///
    /// Текст на санскрите (основной текст) набирается шрифтом санскрита вне
    /// зависимости от выбора: в остальных начертаниях букв для него нет.
    private func verseFont(_ size: CGFloat) -> Font {
        text.isOriginalScript
            ? Fonts.original(size: size * 1.15)
            : Fonts.font(font, size: size, weight: 400)
    }

    /// У санскритского своя высота строки, добавка от Literata там лишняя.
    private func verseSpacing(_ size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        text.isOriginalScript ? 0 : theme.spacing(size, lineHeight: lineHeight)
    }
}
