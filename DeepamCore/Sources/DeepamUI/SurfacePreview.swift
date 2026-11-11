import DeepamCore
import SwiftUI

/// Мини-превью поверхности внутри плитки на экране «Места».
///
/// В макете каждая плитка показывает не иконку, а маленький макет самого места:
/// экран блокировки с часами, сетку иконок, ползунки Пункта управления. Это
/// сделано затем, чтобы человек узнавал место глазами, а не читал название —
/// поэтому здесь рисуются именно эти условные изображения, а не символы.
struct SurfacePreview: View {
    @Environment(\.theme) private var theme
    let surface: Surface

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)

            switch surface {
            case .lockScreen: lockScreen
            case .homeScreen: homeGrid
            case .controlCenter: controls
            case .standBy: standBy
            case .appleWatch: watch
            case .wallpaper: EmptyView()          // сам фон и есть превью
            case .pauseBeforeFeed: pause
            }
        }
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Остальным плиткам границу задаёт тёмная подложка, а обои — это сам
        // набор, и на светлом он сливается с карточкой под ним.
        .overlay {
            if surface == .wallpaper {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.line, lineWidth: 1)
            }
        }
    }

    /// Обои — единственная плитка, где показан наш собственный набор: там наше
    /// изображение и есть содержимое.
    private var background: AnyShapeStyle {
        switch surface {
        case .wallpaper:
            AnyShapeStyle(LinearGradient(colors: [theme.ground, theme.groundSecond],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            AnyShapeStyle(plate)
        }
    }

    /// Остальные плитки изображают экраны системы, а не наши: они тёмные при
    /// любом наборе, иначе условный рисунок сливается с фоном.
    private var plate: Color { theme.chrome }
    private var ink: Color { theme.chromeInk }

    // MARK: - Условные изображения

    private var lockScreen: some View {
        VStack(spacing: 6) {
            Text("9:41")
                .font(theme.ui(15, weight: 500))
                .foregroundStyle(ink)
            VStack(spacing: 3) {
                bar(width: 44)
                bar(width: 30)
            }
        }
    }

    private var homeGrid: some View {
        VStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            // Одна ячейка светлее — это и есть наш виджет
                            // среди чужих иконок.
                            .fill(row == 0 && column == 2
                                  ? ink.opacity(0.85)
                                  : ink.opacity(0.16))
                            .frame(width: 13, height: 13)
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 5) {
            bar(width: 46)
            bar(width: 46)
            bar(width: 46)
        }
    }

    private var standBy: some View {
        Text("9:41")
            .font(theme.ui(24, weight: 500))
            .foregroundStyle(ink)
    }

    private var watch: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(ink.opacity(0.14))
            .frame(width: 30, height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(ink.opacity(0.25), lineWidth: 1)
            )
    }

    private var pause: some View {
        Image(systemName: "hand.raised")
            .font(.system(size: 17))
            .foregroundStyle(ink.opacity(0.7))
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(ink.opacity(0.22))
            .frame(width: width, height: 3)
    }
}
