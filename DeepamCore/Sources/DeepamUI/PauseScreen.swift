import DeepamCore
import SwiftUI

/// Пауза перед лентой — то, что человек видит вместо ленты в первую секунду.
///
/// Экран намеренно пустой: одна карточка и одна кнопка. Здесь нечего изучать и
/// не на что нажимать, кроме «дальше», — иначе пауза превращается в ещё одно
/// приложение, которое отнимает время, а не возвращает его.
///
/// Стих тот же, что на «Сегодня»: пауза не подсовывает случайную строку, а
/// показывает то же самое слово дня — за день оно успевает запомниться.
struct PauseScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.l10n) private var l10n
    let card: Card
    /// Показывать ли оригинал на санскрите над переводом — настройка «Вида».
    let showsOriginal: Bool
    /// Есть ли куда возвращаться по кнопке.
    ///
    /// Ложь означает, что в автоматизации не выбрано приложение: вернуть
    /// человека в соцсеть без её адреса нельзя, общего «открой то, откуда
    /// пришли» iOS не даёт. Раньше экран в этом случае просто закрывался, и
    /// выглядело это поломкой: нажал «Продолжить» — и остался в Deepam.
    let canReturn: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ScreenBackground(glow: .topLeft)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 11))
                        Text(l10n[.pauseWait])
                            .font(theme.ui(11, weight: 500))
                    }
                    .foregroundStyle(theme.textFaint)

                    // Кегль подбирается по длине стиха: карточка в рамке, и
                    // длинный текст при крупном кегле пришлось бы прокручивать.
                    VerseText(parts: card.parts(locale: l10n.locale, showsOriginal: showsOriginal),
                              scale: 0.8)

                    Text(card.reference.uppercased())
                        .font(theme.ui(10, weight: 600))
                        .spaced(1.2)
                        .foregroundStyle(theme.textFaint)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.line, lineWidth: 1))

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button(l10n[canReturn ? .continueAction : .pauseClose], action: onContinue)
                        .buttonStyle(PrimaryButton())

                    // Показывается только в сломанной настройке. Молчать здесь
                    // нельзя: человек видит кнопку, которая как будто не
                    // сработала, и чинить ему нечего — он не знает, что чинить.
                    if !canReturn {
                        Text(l10n[.pauseNoApp])
                            .font(theme.ui(12))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .foregroundStyle(theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
            .padding(.bottom, 34)
            .readableColumn()
            .fitOrScroll()
        }
    }
}
