import SwiftUI

/// Заставка первого экрана: светильник, свет которого едва заметно дышит.
///
/// Раньше здесь стоял зацикленный ролик с пламенем лампы. Новый светильник
/// нарисован один раз, как картинка, а «дыхание» делает сам SwiftUI: медленное
/// колебание яркости и масштаба. Ролик не нужен — вместе с ним уходят проигрыватель,
/// аудиосессия и несколько мегабайт в сборке. При включённом «Уменьшении
/// движения» кадр стоит неподвижно.
struct HeroLantern: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        // Картинка в `overlay` поверх прозрачной подложки: подложка берёт ровно
        // то место, что ей дали, а картинка заполняет его и обрезается по краю.
        // Просто `scaledToFill` вылез бы за экран и сдвинул соседей.
        Color.clear
            .overlay {
                Image("hero", bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(lit ? 1.035 : 1)
                    .brightness(lit ? 0.05 : -0.02)
            }
            .clipped()
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                    lit = true
                }
            }
    }
}
