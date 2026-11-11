import DeepamCore
import SwiftUI

/// Показ пути вместо его описания.
///
/// Текстовая инструкция работает для того, кто уже делал это раньше: он читает
/// названия пунктов и узнаёт их. Тому, кто не делал ни разу, названия не говорят
/// ничего — ему нужно увидеть, куда девается палец. Отсюда этот рисунок.
///
/// Это НЕ запись экрана. Условная схема в тех же цветах, что и плитки на
/// «Местах»: чужие экраны системы там уже рисуются подложкой `chrome`. Запись
/// была бы точнее, но устаревает с каждой версией iOS и требует своей копии на
/// каждый из пяти языков, а схема переводится сама и не весит ничего.
///
/// Схема есть у двух поверхностей из семи — у тех, где люди бросают: пауза
/// уводит в чужое приложение, а на экране блокировки Apple трижды меняла путь.
/// Остальные пять проходятся текстом.
struct HowToAnimation: View {
    @Environment(\.theme) private var theme
    let surface: Surface
    /// Текущая фаза, 0…2. Владеет ею шторка: тот же номер подсвечивает
    /// соответствующий шаг в списке под рисунком, и картинка с текстом не
    /// расходятся.
    let phase: Int

    /// Есть ли у поверхности схема вообще.
    static func exists(for surface: Surface) -> Bool {
        surface == .pauseBeforeFeed || surface == .lockScreen
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.chrome)

            Group {
                switch surface {
                case .pauseBeforeFeed: shortcuts
                case .lockScreen: lockScreen
                default: EmptyView()
                }
            }
            .padding(16)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityHidden(true)
    }

    private var ink: Color { theme.chromeInk }

    // MARK: - Пауза: три экрана «Команд»

    @ViewBuilder
    private var shortcuts: some View {
        switch phase {
        case 0:
            // Библиотека команд, палец идёт на вкладку «Автоматизация».
            VStack(spacing: 10) {
                grid
                Spacer(minLength: 0)
                tabBar(active: 1)
            }
            .overlay(alignment: .bottom) { Tap().offset(x: 0, y: -6) }
        case 1:
            // Пустой список автоматизаций и кнопка «плюс» в углу.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    label("Автоматизация", weight: 600)
                    Spacer()
                    plus
                }
                Spacer(minLength: 0)
                row("Приложение", trailing: "Открыто", lit: true)
                Spacer(minLength: 0)
            }
            .overlay(alignment: .topTrailing) { Tap().offset(x: 4, y: -4) }
        default:
            // Два действия внутри автоматизации, второе с пустым полем.
            VStack(alignment: .leading, spacing: 8) {
                label("Действия", weight: 600)
                row("Пауза со стихом", trailing: nil, lit: true)
                row("Открыть приложение", trailing: "—", lit: false)
                Spacer(minLength: 0)
            }
        }
    }

    /// Сетка плиток библиотеки — узнаётся с одного взгляда.
    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(ink.opacity(0.14))
                            .frame(height: 34)
                    }
                }
            }
        }
    }

    private func tabBar(active: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == active ? ink.opacity(0.9) : ink.opacity(0.16))
                    .frame(height: 22)
            }
        }
    }

    private var plus: some View {
        Image(systemName: "plus")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: 26, height: 26)
            .background(Circle().fill(ink.opacity(0.16)))
    }

    // MARK: - Экран блокировки

    @ViewBuilder
    private var lockScreen: some View {
        switch phase {
        case 0:
            // Часы и долгое нажатие по пустому месту.
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text("9:41")
                    .font(theme.ui(34, weight: 500))
                    .foregroundStyle(ink)
                Spacer(minLength: 0)
            }
            .overlay { Tap(long: true) }
        case 1:
            // Появилась кнопка «Настроить».
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                Text("9:41")
                    .font(theme.ui(24, weight: 500))
                    .foregroundStyle(ink.opacity(0.7))
                Capsule()
                    .fill(ink.opacity(0.9))
                    .frame(width: 104, height: 30)
                Spacer(minLength: 0)
            }
            .overlay(alignment: .center) { Tap().offset(y: 22) }
        default:
            // Пустой слот под часами, в который встаёт карточка со стихом.
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("9:41")
                    .font(theme.ui(24, weight: 500))
                    .foregroundStyle(ink.opacity(0.7))
                slot
                Spacer(minLength: 0)
            }
        }
    }

    /// Слот виджета: пунктирная рамка, в которую въезжает карточка со стихом.
    private var slot: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ink.opacity(0.14))
            .frame(width: 150, height: 40)
            .overlay {
                VStack(spacing: 3) {
                    Capsule().fill(ink.opacity(0.75)).frame(width: 108, height: 4)
                    Capsule().fill(ink.opacity(0.75)).frame(width: 76, height: 4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(ink.opacity(0.5), lineWidth: 1)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Мелочи

    private func label(_ text: String, weight: CGFloat = 400) -> some View {
        Text(text)
            .font(theme.ui(11, weight: weight))
            .foregroundStyle(ink.opacity(0.9))
    }

    /// Строка списка. Подсвеченная — то, что человек только что добавил.
    private func row(_ title: String, trailing: String?, lit: Bool) -> some View {
        HStack {
            Text(title)
                .font(theme.ui(11, weight: lit ? 600 : 400))
                .foregroundStyle(lit ? ink : ink.opacity(0.55))
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(theme.ui(11))
                    .foregroundStyle(ink.opacity(0.55))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(ink.opacity(lit ? 0.2 : 0.1)))
    }
}

/// Касание: расходящееся кольцо и палец.
///
/// Кольцо, а не только палец: без него непонятно, тап это или просто указание.
/// Долгое нажатие отличается тем, что кольцо задерживается на месте, а не
/// гаснет сразу.
private struct Tap: View {
    var long = false

    @State private var out = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.7), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(out ? (long ? 2.2 : 1.7) : 0.5)
                .opacity(out ? 0 : 0.9)

            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6)
                .offset(x: 12, y: 16)
                .scaleEffect(out ? 0.9 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: long ? 1.4 : 0.9)
                .repeatForever(autoreverses: false)) {
                out = true
            }
        }
    }
}
