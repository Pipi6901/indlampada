import DeepamCore
import SwiftUI

/// Куда показывает подсказка. Экраны помечают свои места, а слой поверх
/// собирает рамки и рисует по ним вырез.
struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [Coach.Step: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Coach.Step: Anchor<CGRect>],
                       nextValue: () -> [Coach.Step: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Помечает место, на которое укажет шаг тура.
    ///
    /// Два таких вызова подряд на одном месте НЕ складываются: внешний
    /// перезаписывает значение внутреннего, и остаётся один шаг. Для
    /// нескольких шагов на одном месте есть `coachAnchors(_:)`.
    func coachAnchor(_ step: Coach.Step) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [step: $0] }
    }

    /// То же для нескольких шагов сразу и с условием.
    ///
    /// Пустой список важен: в списке плиток метку иначе забрала бы последняя
    /// отрисованная, и подсветка встала бы не на ту.
    func coachAnchors(_ steps: [Coach.Step]) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { anchor in
            Dictionary(uniqueKeysWithValues: steps.map { ($0, anchor) })
        }
    }
}

/// Слой тура: затемнение с вырезом, подпись, палец и кнопки.
///
/// Слой НЕ перехватывает касания нигде, кроме своих кнопок. Иначе подсказка
/// «нажмите сюда» блокировала бы то самое место, на которое показывает, — а
/// весь смысл в том, чтобы человек нажал сам.
///
/// Мимо подсветки нажать тоже можно. Это сознательно: запирать в туре человека,
/// который передумал, — худшее, что можно сделать с обучением.
struct CoachOverlay: View {
    let coach: Coach
    let step: Coach.Step
    let anchors: [Coach.Step: Anchor<CGRect>]

    var body: some View {
        ZStack {
            // Подсветка живёт в координатах всего экрана: затемнение обязано
            // накрыть и строку состояния, а вырез — совпасть с рамкой места.
            // Одна система координат на то и другое, иначе вырез уезжал бы
            // ровно на высоту строки состояния.
            GeometryReader { geometry in
                CoachSpotlight(step: step,
                               spot: anchors[step].map { geometry[$0] },
                               size: geometry.size,
                               insets: geometry.safeAreaInsets)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Кнопки — в безопасной области. Растянутые на весь экран, они
            // клали «Пропустить» под часы, и нажать на него было нельзя.
            CoachControls(coach: coach, step: step)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }
}

/// Затемнение с дыркой, подпись и палец.
private struct CoachSpotlight: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let step: Coach.Step
    /// Рамка подсвечиваемого места. `nil` — экран не сообщил её. Подпись всё
    /// равно показывается, у нижнего края: молчащий тур хуже тура без выреза.
    let spot: CGRect?
    let size: CGSize
    /// Безопасная область внутри `size`. Слой растянут на весь экран, а
    /// подпись должна стоять там же, где содержимое: на внешнем экране iPhone
    /// Duo справа полоса со строкой состояния и камерой, и по центру всего
    /// экрана подпись съезжала бы вправо, а длинная заходила бы под камеру.
    /// На обычном iPhone в портрете отступов по бокам нет, и ничего не меняется.
    let insets: EdgeInsets

    /// Полосы, куда подпись не ставится: снизу панель вкладок с нижней
    /// кромкой, сверху часы и «Пропустить».
    private let bottomReserved: CGFloat = 150
    private let topReserved: CGFloat = 110

    var body: some View {
        ZStack(alignment: .topLeading) {
            dim
            caption
            if step == .swipe, let spot {
                SwipingFinger().position(x: spot.midX, y: spot.maxY - 10)
            }
        }
    }

    /// Затемнение с дыркой. Дырка вырезается режимом наложения, а не вторым
    /// прямоугольником: иначе на скруглениях остаётся тёмная кайма.
    private var dim: some View {
        Color.black.opacity(0.72)
            .mask {
                Rectangle()
                    .overlay {
                        if let spot {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .frame(width: spot.width + 16, height: spot.height + 16)
                                .position(x: spot.midX, y: spot.midY)
                                .blendMode(.destinationOut)
                        }
                    }
                    .compositingGroup()
            }
    }

    private var caption: some View {
        Text(l10n[step.captionKey])
            .font(theme.ui(14))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.55)))
            .padding(.horizontal, 26)
            // Не шире колонки содержимого: на широком экране строка подписи
            // иначе тянулась бы на девятьсот точек.
            .frame(width: min(usableWidth, ScreenLayout.readableWidth))
            .position(x: insets.leading + usableWidth / 2, y: captionY)
    }

    private var usableWidth: CGFloat {
        max(0, size.width - insets.leading - insets.trailing)
    }

    /// Где стоять подписи.
    ///
    /// Под местом, если под ним есть куда; над ним, если есть куда над ним.
    /// Место выше половины экрана — это не точка, а область: ни под ней, ни над
    /// ней подпись не помещается, и тогда она стоит у нижнего края, поверх
    /// самой области. Туда же — когда места нет вовсе.
    private var captionY: CGFloat {
        let pinned = size.height - bottomReserved - 34
        guard let spot else { return pinned }
        if spot.height > size.height * 0.45 { return pinned }
        if size.height - bottomReserved - spot.maxY >= 100 { return spot.maxY + 66 }
        if spot.minY - topReserved >= 100 { return spot.minY - 66 }
        return pinned
    }
}

/// «Пропустить» наверху и «Дальше» внизу.
private struct CoachControls: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let coach: Coach
    let step: Coach.Step

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button { coach.finish() } label: {
                    Text(l10n[.coachSkip])
                        .font(theme.ui(14, weight: 500))
                        .foregroundStyle(.white.opacity(0.85))
                        // Мишень внутри ярлыка: отступы снаружи кнопки в
                        // область нажатия не входят.
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            Spacer()
            // Кнопка только там, где шаг ничего не ждёт: на остальных её
            // наличие подсказывало бы, что действие можно не делать.
            if !step.needsAction {
                Button(l10n[.coachNext]) { coach.advance() }
                    .buttonStyle(PrimaryButton())
                    .padding(.horizontal, 26)
                    // Та же колонка, что у содержимого и панели вкладок.
                    .readableColumn()
                    // Над панелью вкладок: она занимает свои 92 точки внизу
                    // этого же слоя.
                    .padding(.bottom, 92 + 16)
            }
        }
    }
}

/// Палец, показывающий свайп снизу вверх.
///
/// Рисуется системным символом, а не сторонней анимацией: ради одного жеста
/// тащить в проект целую библиотеку не стоит, а движение здесь простое —
/// подъём с затуханием, повторяющийся с паузой.
struct SwipingFinger: View {
    @State private var lifted = false

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 34))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .offset(y: lifted ? -110 : 0)
            .opacity(lifted ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    lifted = true
                }
            }
    }
}
