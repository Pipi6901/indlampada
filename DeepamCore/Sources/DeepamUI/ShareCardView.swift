import DeepamCore
import SwiftUI

/// Формат картинки для шеринга — макет 12.
enum ShareFormat: String, Hashable, Identifiable, CaseIterable {
    case story
    case square
    case wallpaper

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .story: .formatStory
        case .square: .formatSquare
        case .wallpaper: .formatWallpaper
        }
    }

    /// Размер выгружаемой картинки в пикселях.
    var pixels: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .square: CGSize(width: 1080, height: 1080)
        case .wallpaper: CGSize(width: 1179, height: 2556)
        }
    }

    var aspectRatio: CGFloat { pixels.width / pixels.height }
}

/// Карточка для шеринга.
///
/// Все размеры выражены долями ширины, а не точками: одна и та же вьюха
/// показывается на экране шириной в пару сотен точек и рендерится в 1080
/// пикселей. То, что человек видит перед отправкой, и то, что уйдёт в сторис,
/// — один код, и разъехаться им негде.
struct ShareCardView: View {
    /// Оформление приходит из окружения, поэтому в `ImageRenderer` его надо
    /// проставить руками: у отрисовки вне иерархии экранов своего окружения нет,
    /// и картинка ушла бы со шрифтом по умолчанию вместо выбранного.
    @Environment(\.theme) private var theme
    let card: Card
    /// Оригинал и перевод, как их видит человек на экране «Сегодня».
    let parts: VerseParts
    let style: VerseStyle
    var format: ShareFormat = .story
    /// Подпись «DEEPAM» внизу. Убирается бесплатно — так решено в спеке.
    var showsWordmark: Bool = true
    /// Ширина, от которой считается всё остальное.
    let width: CGFloat

    var body: some View {
        // Колонка не лезет в картинку целиком, когда к переводу добавлен
        // оригинал, — особенно в квадрате. Берётся первая ступенька, при которой
        // она помещается; для коротких стихов это всегда первая.
        ViewThatFits(in: .vertical) {
            column(scale: 1)
            column(scale: 0.86)
            column(scale: 0.74)
            column(scale: 0.62)
            column(scale: 0.52)
        }
        .padding(unit * 8)
        .frame(width: width, height: width / format.aspectRatio, alignment: .leading)
        .background(background)
    }

    private func column(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ReferenceLabel(reference: card.reference, tint: accentColor,
                           size: unit * 2.6, dash: unit * 3.6)

            Spacer(minLength: 0)

            VerseText(parts: parts, scale: verseScale * scale,
                      lineHeight: 1.885, color: verseColor)

            Spacer(minLength: 0)

            if showsWordmark {
                Text("DEEPAM")
                    .font(theme.ui(unit * 2.4, weight: 600))
                    .kerning(unit * 0.9)
                    .foregroundStyle(verseColor.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Фон карточки — тот же, что человек выбрал для приложения: отправленная
    /// картинка должна выглядеть как его экран, а не как чужая заготовка.
    @ViewBuilder private var background: some View {
        if let scene = theme.scene {
            SceneBackground(scene: scene, variant: format == .square ? .square : .tall)
        } else {
            style.fill
        }
    }

    /// На картинке цвет текста задаёт она сама, а не набор, который она закрыла.
    private var verseColor: Color { theme.scene == nil ? style.textColor : theme.text }
    private var accentColor: Color { theme.scene == nil ? style.accentColor : theme.accent }

    /// Базовая единица — сотая доля ширины. От неё считаются отступы и кегли,
    /// поэтому карточка выглядит одинаково в любом размере.
    private var unit: CGFloat { width / 100 }

    /// Кегли стиха заданы в точках экрана «Сегодня» (ширина около 393), а здесь
    /// ширина — любая. Это отношение переводит одно в другое; 0,9 — запас, потому
    /// что на картинке вокруг текста поля шире, чем на экране.
    private var verseScale: CGFloat { unit / 3.93 * 0.9 }
}

/// Экран «Поделиться» — макет 12.
///
/// Карточка занимает всё свободное место, сохраняя пропорции формата; под ней
/// выбор формата, тумблер подписи и кнопка отправки.
struct ShareScreen: View {
    let card: Card
    @Bindable var settings: AppSettings
    let entitlements: any EntitlementStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var l10n
    @Environment(\.theme) private var theme

    @State private var format: ShareFormat = .story
    @State private var showsWordmark = true

    var body: some View {
        ZStack {
            ScreenBackground(glow: .bottomLeft)

            VStack(spacing: 16) {
                header
                preview
                Segmented(selection: $format, items: ShareFormat.allCases) { l10n[$0.titleKey] }
                wordmarkToggle

                ShareLink(item: rendered, preview: SharePreview(card.reference, image: rendered)) {
                    Text(l10n[.sendAction])
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 34)
            // По высоте экран и так подстраивается — карточка берёт ту высоту,
            // что осталась. По ширине ему нужна колонка: иначе на широком
            // экране iPhone Duo кнопка и переключатели растянулись бы на всю
            // ширину.
            .readableColumn()
        }
    }

    private var header: some View {
        HStack {
            Text(l10n[.shareTitle])
                .font(theme.display(26))
                .foregroundStyle(theme.text)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textFaint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n[.close])
        }
    }

    /// Ширину карточки диктует доступная высота: у сторис пропорции 9:16, и
    /// если считать от ширины экрана, карточка не поместится по вертикали.
    private var preview: some View {
        GeometryReader { geometry in
            let fitted = min(geometry.size.width, geometry.size.height * format.aspectRatio)
            ShareCardView(card: card, parts: parts, style: style, format: format,
                          showsWordmark: showsWordmark, width: fitted)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(theme.isLight ? 0.14 : 0.3), radius: 24, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var wordmarkToggle: some View {
        Toggle(isOn: $showsWordmark) {
            Text(l10n[.wordmark])
                .font(theme.ui(13))
                .foregroundStyle(theme.textMuted)
        }
        .tint(theme.accent)
    }

    private var style: VerseStyle { settings.style(for: .app) }

    /// То же, что на «Сегодня»: оригинал на санскрите над переводом, если он включён.
    private var parts: VerseParts {
        card.parts(locale: l10n.locale, showsOriginal: settings.showsOriginal)
    }

    /// Отрисовка в полном размере: карточка на экране и картинка на выходе —
    /// одна вьюха, отличается только ширина.
    @MainActor private var rendered: Image {
        let renderer = ImageRenderer(
            content: ShareCardView(card: card, parts: parts, style: style, format: format,
                                   showsWordmark: showsWordmark,
                                   width: format.pixels.width)
                .themed(theme)
                // Язык интерфейса уходит в картинку вместе с оформлением: от него
                // зависят направление письма и разрядка подписей. Без него
                // отправленная карточка у основного текста вышла бы слева
                // направо и с разрядкой, которая рвёт санскритские буквы.
                .localized(l10n.locale)
        )
        renderer.scale = 1
        #if canImport(UIKit)
        if let image = renderer.uiImage {
            return Image(uiImage: image)
        }
        #endif
        return Image(systemName: "photo")
    }
}
