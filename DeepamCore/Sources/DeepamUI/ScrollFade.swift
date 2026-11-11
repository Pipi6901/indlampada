import SwiftUI

/// Растворяет содержимое прокрутки у верхнего и нижнего края.
///
/// Без этого текст уезжает под строку состояния и под панель вкладок обрубленным
/// по прямой — видно половину строки, срезанную ровной линией. Особенно заметно
/// снизу: панель плавающая, и под ней остаётся полоска, где строка просто
/// заканчивается посреди буквы.
///
/// Сделано маской, а не заливкой поверх. Заливка требует знать, какого цвета
/// фон, а под содержимым может лежать картинка — тогда пришлось бы гасить её
/// вместе с текстом. Маска убирает только само содержимое, фон остаётся целым.
///
/// Высоты в точках, а не в долях экрана. Доля привязывает величину растворения к
/// росту телефона, хотя обрезается строка текста — а она везде одна и та же.
struct ScrollFade: ViewModifier {
    /// Сверху короче: там уезжает заголовок, и длинный градиент съел бы его
    /// целиком ещё до прокрутки.
    static let defaultTop: CGFloat = 26
    /// Снизу длиннее — растворение должно перекрыть зазор до плавающей панели.
    static let defaultBottom: CGFloat = 56

    var top: CGFloat = ScrollFade.defaultTop
    var bottom: CGFloat = ScrollFade.defaultBottom

    func body(content: Content) -> some View {
        content
            // Отступы содержимого равны высоте растворения. Без них крайние
            // строки в покое стоят прямо в градиенте: заголовок сверху выцветал
            // бы всегда, а до нижней строки нельзя было бы «доскроллить» —
            // она упиралась бы в конец списка уже наполовину растворённой.
            .contentMargins(.top, top, for: .scrollContent)
            .contentMargins(.bottom, bottom, for: .scrollContent)
            .mask {
                // Никакого `ignoresSafeArea`: маска обязана совпадать с рамкой
                // самой прокрутки. Растянутая на вырез и на нижнюю полосу, она
                // уводит верхнее растворение выше видимой границы — фейда сверху
                // не видно вовсе, — а нижнее, наоборот, вдвигает внутрь текста.
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: top)
                    Color.black
                    LinearGradient(colors: [.black, .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom)
                }
            }
    }
}

extension View {
    /// Растворение содержимого у краёв прокрутки. См. `ScrollFade`.
    func scrollFade(top: CGFloat = ScrollFade.defaultTop,
                    bottom: CGFloat = ScrollFade.defaultBottom) -> some View {
        modifier(ScrollFade(top: top, bottom: bottom))
    }
}
