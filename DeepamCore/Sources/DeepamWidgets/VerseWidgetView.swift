#if os(iOS)
import DeepamCore
import DeepamUI
import SwiftUI
import WidgetKit

/// Вид виджета для всех семейств.
///
/// Одна вьюха на все размеры, а не шесть отдельных: содержимое одно и то же,
/// разное только сколько его помещается. Разводить это по файлам значило бы
/// шесть раз чинить одну и ту же опечатку.
public struct VerseWidgetView: View {
    let entry: VerseEntry

    @Environment(\.widgetFamily) private var family
    /// `false` — система убрала подложку. Так бывает в StandBy: там виджет
    /// рисуется на чёрном.
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    public init(entry: VerseEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .accessoryInline:
            // Одна строка без переносов: система обрежет сама, поэтому ссылка
            // важнее текста — по ней можно найти стих целиком.
            Text(entry.reference)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
            }

        case .accessoryRectangular:
            lockScreen

        default:
            if isStandBy && !entry.isPro {
                lockedStandBy
            } else {
                home
            }
        }
    }

    /// StandBy показывает только маленькие виджеты и только без подложки.
    ///
    /// Других признаков у системы нет. Если iOS уберёт подложку маленькому
    /// виджету где-то ещё — например, на экране блокировки iPad, — без подписки
    /// там тоже встанет замок. Проверять на устройстве.
    private var isStandBy: Bool {
        family == .systemSmall && !showsBackground
    }

    /// StandBy без подписки: стих виден, но не читается, поверх замок.
    ///
    /// Не пустая плитка с замком: размытый стих показывает, что именно здесь
    /// будет, и дразнит, а не просто запрещает. Тап ведёт на пейволл.
    private var lockedStandBy: some View {
        ZStack {
            homeContent
                .blur(radius: 7)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(lockedNote)
                    .font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
        }
        .containerBackground(for: .widget) {
            background
        }
        .widgetURL(URL(string: "deepam://pro"))
    }

    /// Своего выбора языка у расширения нет — берётся настройка приложения, а
    /// без неё язык устройства, как и у подписи в галерее виджетов.
    private var lockedNote: String {
        L10n(AppSettings().language ?? .detect())[.standByLocked]
    }

    /// Прямоугольный виджет на экране блокировки.
    ///
    /// Здесь три строки мелким кеглем и больше ничего. Раньше сюда клали полный
    /// стих: система обрезала его многоточием посреди слова, и на карточке-
    /// продолжении выходило «ты, которого Я взял от концов земли и приз…» —
    /// набор слов.
    ///
    /// Теперь текст режется по смыслу (см. `Card.shortText`), а ссылка стоит
    /// первой: она короткая, всегда влезает целиком и позволяет найти стих, даже
    /// если сам он не поместился.
    private var lockScreen: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(entry.reference)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .widgetAccentable()

            lockText
        }
        .multilineTextAlignment(entry.lockAlignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity,
               alignment: entry.lockAlignment == .center ? .center : .leading)
    }

    /// Текст на экране блокировки. Оригинал сюда не кладём: места на три строки,
    /// и важнее, чтобы влез перевод. Ветка `isOriginalScript` нужна на случай языка,
    /// в котором основной текст — сам оригинал (сейчас такого нет).
    @ViewBuilder private var lockText: some View {
        let shown = entry.lockLength == .short ? entry.shortText : entry.text
        if shown.isOriginalScript {
            // У шрифта санскрита высота строки больше, чем у латиницы, поэтому кегль мельче.
            Text(shown)
                .font(Fonts.original(size: 11))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(shown)
                .font(verse(12))
                .lineLimit(2)
                // Ужать мелкий текст лучше, чем оборвать: на два кегля мельче
                // строка ещё читается, а многоточие уносит половину фразы.
                .minimumScaleFactor(0.8)
        }
    }

    /// Шрифт стиха — тот же, что в приложении.
    ///
    /// Начертания лежат в ресурсах `DeepamUI`, а расширение её линкует, так что
    /// регистрация в процессе происходит сама при первом обращении.
    private func verse(_ size: CGFloat) -> Font {
        Fonts.font(entry.lockFont, size: size, weight: 400)
    }

    private var homeAlignment: HorizontalAlignment {
        entry.widgetAlignment == .center ? .center : .leading
    }

    private func homeVerse(_ size: CGFloat) -> Font {
        Fonts.font(entry.widgetFont, size: size, weight: 400)
    }

    private var alignment: HorizontalAlignment {
        entry.lockAlignment == .center ? .center : .leading
    }

    /// Виджеты на рабочем столе и в StandBy: текст, под ним ссылка.
    ///
    /// Текст стоит по центру по вертикали, а не жмётся к верхнему краю: стих
    /// короче доступного места — обычное дело, и прижатый вверх он оставлял под
    /// собой пустую половину плитки.
    private var home: some View {
        homeContent
            .containerBackground(for: .widget) {
                background
            }
    }

    /// Текст и ссылка без подложки. Отдельно от `home`, потому что ими же
    /// рисуется размытый стих под замком в StandBy, а подложку виджет
    /// объявляет один раз, у корня.
    ///
    /// Кегль подбирается ступенями, как на экране «Сегодня»: берётся первая
    /// ступень, при которой стих помещается. Стихи разной длины (от пяти слов до
    /// абзаца), а виджет маленький, и один кегль на всё то обрезал бы длинные,
    /// то терялся бы на коротких. Ступени подобраны расчётом по всему корпусу с
    /// настоящими метриками шрифтов.
    private var homeContent: some View {
        ViewThatFits(in: .vertical) {
            column(0)
            column(1)
            column(2)
            column(3)
            column(4)
            column(5)
            column(6)
            column(7)
        }
    }

    /// Одна ступень: оригинал (если он есть) и основной текст заданного кегля.
    private struct Step {
        /// Кегль оригинала над переводом; `nil` — оригинала в этой ступени нет.
        let original: CGFloat?
        /// Кегль основного текста: перевода (или оригинала, если он и есть основной текст).
        let text: CGFloat
    }

    /// Ступени от крупной к мелкой. Сначала оригинал с переводом (если он
    /// включён и размер позволяет), потом один перевод — он читается лучше, чем
    /// два текста по девять точек.
    private var steps: [Step] {
        let small = family == .systemSmall
        let large = family == .systemLarge
        if entry.text.isOriginalScript {
            let sizes: [CGFloat] = small ? [18, 15, 13, 11, 9.5]
                : large ? [30, 26, 22, 19, 16, 13]
                : [20, 17, 15, 13, 11, 9.5]
            return sizes.map { Step(original: nil, text: $0) }
        }
        var out: [Step] = []
        if shownOriginal != nil {
            let pairs: [(CGFloat, CGFloat)] = large ? [(24, 17), (21, 15), (18, 13), (15, 11)]
                : [(16, 12), (14, 11), (12, 10)]
            out += pairs.map { Step(original: $0.0, text: $0.1) }
        }
        let sizes: [CGFloat] = small ? [14, 12.5, 11, 10, 9]
            : large ? [19, 16, 13, 11]
            : [14, 12, 10.5, 9]
        out += sizes.map { Step(original: nil, text: $0) }
        return out
    }

    private func column(_ index: Int) -> some View {
        let all = steps
        let step = all[min(index, all.count - 1)]
        // Предел строк и сжатие — только у самой мелкой ступени. Если поставить
        // их всем, любая ступень «влезала» бы за счёт обрезки, и подбор терял бы
        // смысл.
        let isLast = index >= all.count - 1
        return VStack(alignment: homeAlignment, spacing: 8) {
            Spacer(minLength: 0)
            if let size = step.original, let original = shownOriginal {
                originalBlock(original, size: size, limit: isLast ? 3 : nil, shrinks: isLast)
            }
            if entry.text.isOriginalScript {
                // Основной текст — сам оригинал: он единственный и занимает всё.
                originalBlock(entry.text, size: step.text, limit: isLast ? lineLimit : nil, shrinks: isLast)
            } else {
                Text(entry.text)
                    .font(homeVerse(step.text))
                    .foregroundStyle(verseColor)
                    .lineSpacing(step.text * 0.3)
                    .minimumScaleFactor(isLast ? 0.6 : 1)
                    .lineLimit(isLast ? lineLimit : nil)
            }

            Text(entry.reference)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(referenceColor)
                .tracking(entry.text.isOriginalScript ? 0 : 0.4)
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(entry.widgetAlignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: entry.widgetAlignment == .center ? .center : .leading)
    }

    /// Блок оригинала: санскрит слева направо, шрифтом Tiro Devanagari Sanskrit. Строки стиха
    /// (полустишия) разделены переносом — он остаётся как в корпусе.
    private func originalBlock(_ text: String, size: CGFloat, limit: Int?, shrinks: Bool) -> some View {
        Text(text)
            .font(Fonts.original(size: size))
            .foregroundStyle(verseColor)
            .minimumScaleFactor(shrinks ? 0.6 : 1)
            .lineLimit(limit)
            .multilineTextAlignment(entry.widgetAlignment == .center ? .center : .leading)
            .frame(maxWidth: .infinity,
                   alignment: entry.widgetAlignment == .center ? .center : .leading)
    }

    /// В маленьком виджете и в StandBy оригинал не показываем: на двух строках
    /// ему негде развернуться, а смысл даёт перевод.
    private var shownOriginal: String? {
        family == .systemSmall ? nil : entry.original
    }

    /// Цвета набора годятся, только пока под текстом лежит его подложка.
    ///
    /// Без неё — в StandBy — виджет стоит на чёрном, и у светлых наборов
    /// («Пергамент», «Заря», «Опал») тёмный текст пропадал целиком.
    private var verseColor: Color {
        showsBackground ? Color(hex: palette.text) : .white
    }

    private var referenceColor: Color {
        showsBackground ? Color(hex: palette.accent) : .white.opacity(0.6)
    }

    /// Палитра берётся у картинки, когда она выбрана: цвет текста и акцента
    /// должен считаться от того, что реально лежит под ними.
    private var palette: (background: UInt32, second: UInt32, text: UInt32, accent: UInt32) {
        entry.scene?.palette ?? entry.style.palette
    }

    /// Широкий виджет и StandBy берут горизонтальную версию картинки, остальные
    /// квадратную: одна и та же композиция в этих пропорциях не живёт.
    @ViewBuilder private var background: some View {
        if let scene = entry.scene {
            SceneBackground(scene: scene, variant: family == .systemMedium ? .wide : .square)
        } else {
            Color(hex: palette.background)
        }
    }

    /// Предел строк самой мелкой ступени: дальше стих обрезается, а не вылезает
    /// за виджет.
    private var lineLimit: Int {
        switch family {
        case .systemSmall: 6
        case .systemLarge: 16
        default: 5
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Объявление виджета. `@main` живёт в расширении: там же права на группу и
/// свой Info.plist, поэтому здесь только тело.
public struct DeepamWidget: Widget {
    public init() {}

    private var gallery: L10n { L10n(AppSettings().language ?? .detect()) }

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeepamVerse", provider: VerseProvider()) { entry in
            VerseWidgetView(entry: entry)
        }
        // Подпись в галерее виджетов берётся из настройки приложения, а если
        // человек до неё не дошёл — из языка устройства. Своего выбора языка у
        // расширения нет, и статические строки остались бы русскими для всех.
        .configurationDisplayName(gallery[.widgetDisplayName])
        .description(gallery[.widgetDescription])
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
    }
}
#endif
