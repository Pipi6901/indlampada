import SwiftUI

/// Шторка высотой по содержимому.
///
/// `presentationDetents` принимает только конкретные числа: варианта «по
/// содержимому» среди них нет — он появился лишь в iOS 18, а мы держим 17.
/// Из-за фиксированной высоты нижний отступ гулял: на языке с более короткими
/// строками содержимое сжималось, а лист оставался прежним, и под текстом
/// зияла пустота. Поэтому высоту измеряем и передаём в детент.
///
/// Обязательное условие: внутри не должно быть растягивающихся `Spacer` —
/// иначе содержимое займёт всю выданную высоту, измерение вернёт её же, и
/// уменьшиться лист уже не сможет.
struct FittedSheet: ViewModifier {
    /// Выше не растём: дальше содержимое прокручивается, а не выталкивает
    /// шторку за верх экрана.
    var maximum: CGFloat = 640

    @State private var height: CGFloat = 320

    /// Содержимое лежит в прокрутке. Высоту шторки она не меняет: внутри
    /// прокрутки содержимое получает свою естественную высоту, её и меряем.
    /// Зато когда экран ниже содержимого — внешний экран iPhone Duo около 678
    /// точек, — система ужимает шторку до экрана, и без прокрутки низ с
    /// кнопкой просто обрезался бы. Влезает — прокрутка не пружинит и
    /// незаметна.
    func body(content: Content) -> some View {
        ScrollView {
            content
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: HeightKey.self, value: geometry.size.height)
                    }
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        // Прокрутка иначе добавила бы снизу отступ под полоску «Домой», и
        // содержимое высотой ровно в шторку стало бы выше неё — на каждом
        // обычном iPhone шторка начинала бы пружинить. Без прокрутки этого
        // отступа не было, и нижние поля листов подбирались без него.
        .ignoresSafeArea(.container, edges: .bottom)
        .onPreferenceChange(HeightKey.self) { value in
            Task { @MainActor in height = value }
        }
        .presentationDetents([.height(min(height, maximum))])
    }

    private struct HeightKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
}

extension View {
    /// Высота шторки — по содержимому. См. `FittedSheet`.
    func fittedSheet(maximum: CGFloat = 640) -> some View {
        modifier(FittedSheet(maximum: maximum))
    }
}
