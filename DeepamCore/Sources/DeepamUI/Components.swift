import DeepamCore
import SwiftUI

/// Компоненты макета, перенесённые по свойствам один в один.
///
/// Значения ниже — не подбор на глаз: у четырёх компонентов из `.pen` читаются
/// все свойства целиком, и они выписаны здесь как есть. Если что-то меняется в
/// макете, менять надо тут, а не в экранах.

// MARK: - component/ButtonPrimary

/// Кнопка 280×58, радиус 29, подпись 17/600.
///
/// `ButtonStyle` не умеет читать окружение: `makeBody` — не тело вью, и
/// `@Environment` в нём молча отдаёт значение по умолчанию. Поэтому оформление
/// достаётся во вложенной вью, а стиль только собирает её.
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: Configuration
        @Environment(\.theme) private var theme

        var body: some View {
            configuration.label
                .font(theme.ui(17, weight: 600))
                .spaced(0.1)
                .foregroundStyle(theme.buttonText)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .fill(theme.buttonFill)
                        // У SwiftUI нет spread, но радиус и смещение дают тот
                        // же мягкий подсвет снизу, что в макете.
                        .shadow(color: theme.buttonFill.opacity(0.18), radius: 14, y: 8)
                )
                // Без этого нажималась бы только сама подпись: фон нарисован
                // модификатором и в область нажатия сам по себе не входит.
                .contentShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .opacity(configuration.isPressed ? 0.86 : 1)
        }
    }
}

// MARK: - component/ButtonGhost

/// Кнопка 280×58, радиус 29, обводка 1pt, подпись 17/500.
struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: Configuration
        @Environment(\.theme) private var theme

        var body: some View {
            configuration.label
                .font(theme.ui(17, weight: 500))
                .foregroundStyle(theme.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .strokeBorder(theme.line, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

// MARK: - Ссылка над стихом

/// «— ОТ МАТФЕЯ 11:28 · СИНОДАЛЬНЫЙ»: тире, прописные, широкий трекинг.
///
/// Издание в подписи стоит намеренно: у пяти языков пять разных переводов, и
/// человек должен видеть, что именно он читает, не заходя в настройки.
struct ReferenceLabel: View {
    @Environment(\.theme) private var theme
    let reference: String
    /// Пустая строка убирает часть с изданием — так надо в предпросмотрах,
    /// где места мало и название перевода только мешает.
    var edition: String = ""
    /// Цвет задаётся снаружи: на карточке набора он берётся из набора, а не
    /// из оформления приложения.
    var tint: Color?
    /// Кегль и длина тире — параметры, потому что тот же компонент рисуется и
    /// на экране, и внутри картинки для шеринга шириной в 1080 пикселей.
    var size: CGFloat = 10
    var dash: CGFloat = 14

    var body: some View {
        HStack(spacing: dash * 0.57) {
            Rectangle()
                .fill(tint ?? theme.textFaint)
                .frame(width: dash, height: max(1, dash / 14))
            Text(label.uppercased())
                .font(theme.ui(size, weight: 600))
                .spaced(size * 0.12)
                .foregroundStyle(tint ?? theme.textFaint)
        }
    }

    private var label: String {
        edition.isEmpty ? reference : "\(reference) · \(edition)"
    }
}

// MARK: - Пилюля контекста

/// «Кто это говорит и когда» — вход в шторку с контекстом.
struct ContextPill: View {
    @Environment(\.theme) private var theme
    let action: () -> Void

    @Environment(\.l10n) private var l10n

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 11, weight: .medium))
                Text(l10n[.contextPill])
                    .font(theme.ui(12))
            }
            .foregroundStyle(theme.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(theme.text.opacity(0.11))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - component/TabBar

/// Плавающая капсула 361×66, радиус 33, внутренний отступ 6. Активная вкладка —
/// плашка с радиусом 27.
///
/// В макете заливка и обводка заданы конкретными цветами, но набор из «Вида»
/// красит всё приложение, и фиолетово-серая капсула на «Пергаменте» выглядела бы
/// чужой. Поэтому цвета выведены из набора и на «Лаванде» совпадают с макетом.
///
/// Капсула — матовое стекло, а не заливка: сплошной прямоугольник поверх
/// картинки читался как чужой блок, наложенный на фон. Материал пропускает
/// изображение и размывает его, панель перестаёт быть «дыркой» в экране.
///
/// Тёмной она остаётся при любом наборе, и для этого материалу навязана тёмная
/// схема. Причина не в красоте: иконки вкладок — готовая объёмная графика в
/// светлых тонах, перекрасить её нельзя (заливка цветом съедает объём), и на
/// светлом стекле поверх «Пастыря» или «Пергамента» она попросту исчезает.
struct TabBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    @Binding var selection: Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Подписи и плашка активной вкладки. Панель тёмная при любом наборе,
    /// поэтому цвет светлый и от набора не зависит.
    private var ink: Color { .white }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                item(tab)
            }
        }
        .padding(6)
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .fill(.ultraThinMaterial)
                // Тёмная схема — материалу, а не всей панели: иначе вместе с ним
                // перекрасились бы подписи вкладок.
                .environment(\.colorScheme, .dark)
                // Тон поверх стекла, и он зависит от того, что под панелью.
                // На «Пастыре» и «Облаках» низ картинки светлый: одного материала
                // там мало, подписи давали 1,4:1 вместо нужных 4,5:1.
                //
                // Значение подобрано замером, а не на глаз. Сначала стояло 0,60 —
                // контраст оно давало с запасом, но стекло превращало в глухую
                // плашку, ради которой всё и затевалось. 0,34 держит 7:1 у
                // активной подписи и оставляет картинку видимой.
                .overlay(
                    RoundedRectangle(cornerRadius: 33, style: .continuous)
                        .fill(.black.opacity(theme.isLight ? 0.34 : 0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 33, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
                // Тень мягкая и почти без смещения: она нужна, чтобы отделить
                // панель от содержимого, а не читаться отдельным пятном. Плотный
                // чёрный на насыщенном фоне вроде «Лаванды» именно им и выглядел
                // — тёмный ореол виден сам по себе, хотя тень должна лишь
                // намекать на подъём.
                .shadow(color: .black.opacity(theme.isLight ? 0.10 : 0.22),
                        radius: 20, y: 6)
        }
    }

    private func item(_ tab: Tab) -> some View {
        Button {
            guard selection != tab else { return }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { selection = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 26, height: 26)
                    // Активная вкладка — цвет акцента, остальные приглушены.
                    .foregroundStyle(selection == tab ? theme.accent : ink.opacity(0.45))

                Text(l10n[tab.titleKey])
                    .font(theme.ui(10, weight: 500))
                    .foregroundStyle(ink.opacity(selection == tab ? 1 : 0.78))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selection == tab {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(ink.opacity(0.1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n[tab.titleKey])
        .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
    }
}

/// Слот таб-бара из макета: высота 92, отступы [14, 16, 12, 16].
struct TabBarSlot: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Tab

    var body: some View {
        TabBar(selection: $selection)
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }
}
