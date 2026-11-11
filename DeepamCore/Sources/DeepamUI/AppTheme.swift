import DeepamCore
import SwiftUI

/// Оформление всего приложения, выведенное из выбранного набора.
///
/// Набор в «Виде» задаёт не только карточку со стихом, а весь экран: фон,
/// плашки, линии, текст и акцент. Поэтому палитра здесь не константы, а
/// производные от четырёх цветов набора — иначе выбор «Пергамента» покрасил бы
/// один прямоугольник, а всё вокруг осталось бы тёмно-фиолетовым.
///
/// Промежуточные цвета считаются смешиванием фона с текстом. Так набор
/// достаточно описать четырьмя значениями, и любой новый автоматически
/// получает согласованные плашки и линии.
struct AppTheme: Sendable, Hashable {
    let style: VerseStyle
    let font: VerseFont
    /// Выбранный фон-изображение. Когда он есть, палитра берётся из него: цвета
    /// плашек и кнопок должны считаться от картинки, а не от набора, который она
    /// собой закрыла.
    var scene: VerseScene? = nil

    private var palette: (background: UInt32, second: UInt32, text: UInt32, accent: UInt32) {
        scene?.palette ?? style.palette
    }

    private var background: UInt32 { palette.background }
    private var second: UInt32 { palette.second }
    private var foreground: UInt32 { palette.text }

    /// Светлый ли набор — от этого зависят тени и насыщенность подложек.
    var isLight: Bool { AppTheme.luminance(background) > 0.5 }

    // MARK: - Цвета

    var ground: Color { Color(hex: background) }
    var groundSecond: Color { Color(hex: second) }
    /// Плашки и карточки: фон, слегка сдвинутый к тексту.
    var raised: Color { mix(background, foreground, 0.07) }
    var line: Color { mix(background, foreground, 0.17) }
    var text: Color { Color(hex: foreground) }

    /// Приглушённый и совсем бледный текст: подписи разделов, названия наборов,
    /// дата и ссылка на отрывок.
    ///
    /// Над картинкой приглушения нет вовсе. Приглушить — значит подмешать к
    /// тексту фон, а это работает ровно пока фон под всей надписью один и тот же.
    /// Под фотографией светлота гуляет от буквы к букве, и любой промежуточный
    /// серый где-нибудь да сливается: на «Старой книге» бледная подпись пропадает
    /// в светлом, на «Ночной фреске» — в тёмном. Поэтому над картинкой цвет
    /// берётся полный, а иерархия остаётся за кеглем, насыщенностью и разрядкой.
    var textMuted: Color { scene == nil ? mix(background, foreground, 0.72) : text }
    var textFaint: Color { scene == nil ? mix(background, foreground, 0.48) : text }
    var accent: Color { Color(hex: palette.accent) }

    /// Тёмная подложка под условные изображения чужих экранов системы —
    /// плитки на «Местах» и панель вкладок.
    ///
    /// Затемнением фона, а не смешиванием с цветом текста: на «Пергаменте»
    /// текст тёмный, а на «Лаванде» белый, и одна формула на оба случая даёт
    /// противоположный результат — на «Лаванде» подложка вышла бы светлее фона
    /// и слилась бы с ним.
    var chrome: Color { mix(background, 0x000000, isLight ? 0.72 : 0.45) }
    /// Штрихи на этой подложке. Она тёмная при любом наборе, поэтому светлые.
    var chromeInk: Color { mix(background, 0xFFFFFF, 0.88) }

    /// Фон шторки: сверху чуть светлее фона экрана, чтобы лист читался как слой
    /// поверх, а не как продолжение того же полотна.
    var sheetFill: LinearGradient {
        LinearGradient(colors: [mix(background, foreground, 0.12), ground],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Заливка главной кнопки и текст на ней. На тёмных наборах кнопка
    /// светлая, на светлых — тёмная: контраст важнее единообразия.
    var buttonFill: Color { mix(background, foreground, isLight ? 0.88 : 0.92) }
    /// Всегда цвет фона: заливка кнопки — почти цвет текста, и фон на ней даёт
    /// максимальный контраст при любом наборе.
    var buttonText: Color { ground }

    // MARK: - Шрифты

    /// Крупный текст: стих, заголовки экранов.
    func display(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        Fonts.font(font, size: size, weight: weight)
    }

    /// Мелкий текст интерфейса: подписи, кнопки, строки настроек.
    ///
    /// Семейство то же самое, что у `display`: выбор в «Виде» меняет шрифт
    /// всего приложения, а не одного стиха. Два имени оставлены потому, что по
    /// месту вызова видно назначение текста, — если однажды понадобится развести
    /// интерфейс и чтение по разным начертаниям, менять придётся здесь, а не в
    /// сотне мест.
    func ui(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        Fonts.font(font, size: size, weight: weight)
    }

    /// Межстрочный интервал под заданную высоту строки.
    ///
    /// `lineHeight` здесь — полная высота строки в долях кегля, а не добавка
    /// сверх собственной высоты шрифта. Только так абзац сохраняет высоту при
    /// смене начертания.
    func spacing(_ size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        Fonts.lineSpacing(font, size: size, lineHeight: lineHeight)
    }

    // MARK: - Смешивание

    private func mix(_ from: UInt32, _ to: UInt32, _ amount: Double) -> Color {
        Color(hex: AppTheme.blend(from, to, amount))
    }

    static func blend(_ from: UInt32, _ to: UInt32, _ amount: Double) -> UInt32 {
        var out: UInt32 = 0
        for shift in [16, 8, 0] {
            let a = Double((from >> UInt32(shift)) & 0xFF)
            let b = Double((to >> UInt32(shift)) & 0xFF)
            let value = UInt32((a + (b - a) * amount).rounded())
            out |= min(255, value) << UInt32(shift)
        }
        return out
    }

    /// Воспринимаемая яркость по Rec. 709 — по ней решается, светлый набор
    /// или тёмный.
    static func luminance(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme(style: .night, font: .literata)
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    func themed(_ theme: AppTheme) -> some View {
        environment(\.theme, theme)
    }
}
