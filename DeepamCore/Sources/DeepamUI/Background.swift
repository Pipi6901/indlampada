import DeepamCore
import SwiftUI

/// Фон экрана: вертикальный градиент из набора и мягкое пятно света.
///
/// Цвета берутся из темы, а не задаются константами: набор в «Виде» красит всё
/// приложение. Положение пятна разное на разных экранах — оно задаёт, куда
/// смотреть, — поэтому это параметр.
struct ScreenBackground: View {
    enum Glow {
        case bottomLeft
        case topLeft

        var offset: (x: CGFloat, y: CGFloat) {
            switch self {
            case .bottomLeft: (-70, 180)   // из макета «Сегодня»
            case .topLeft: (-100, 60)      // из макета «Места»
            }
        }

        var size: CGFloat {
            switch self {
            case .bottomLeft: 540
            case .topLeft: 420
            }
        }
    }

    var glow: Glow?

    @Environment(\.theme) private var theme

    /// `ignoresSafeArea` стоит на самом внешнем слое, и меряет размеры уже он.
    ///
    /// Раньше `GeometryReader` был снаружи, а обрезка картинки — внутри него: он
    /// получал размер безопасной области, картинка обрезалась по ней, и на
    /// разных вкладках она вставала по-разному, а низ с сюжетом не показывался
    /// вовсе.
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let scene = theme.scene {
                picture(scene)
            } else {
                gradient
                glowLayer
            }
        }
        .ignoresSafeArea()
    }

    /// Картинка во весь экран, подложка под текстом и фейд под строкой
    /// состояния.
    private func picture(_ scene: VerseScene) -> some View {
        Color.clear
            .overlay {
                GeometryReader { geometry in
                    FocusedPicture(scene: scene, size: geometry.size)
                }
            }
            .overlay { SceneScrim(scene: scene) }
            .overlay(alignment: .top) { TopFade(scene: scene) }
            .clipped()
    }

    private var gradient: some View {
        LinearGradient(
            stops: [.init(color: theme.groundSecond, location: 0),
                    .init(color: theme.ground, location: 0.55),
                    .init(color: theme.ground, location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Пятно света есть только у цветных наборов: на картинке оно читалось бы
    /// как засветка объектива.
    @ViewBuilder
    private var glowLayer: some View {
        if let glow {
            GeometryReader { geometry in
                RadialGradient(
                    colors: [theme.accent.opacity(theme.isLight ? 0.10 : 0.18), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: glow.size / 2
                )
                // Координаты заданы в кадре макета 393×852 и масштабируются
                // под реальный экран, иначе на широких моделях свет уезжает.
                .frame(width: glow.size, height: glow.size)
                .offset(x: glow.offset.x * geometry.size.width / 393,
                        y: glow.offset.y * geometry.size.height / 852)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Картинка фона, подогнанная под пропорции экрана.
///
/// Раньше во весь экран всегда шёл высокий вариант, обрезанный по центру. На
/// обычном iPhone пропорции экрана и картинки совпадают, и резать нечего. На
/// iPhone Duo экраны почти квадратные: в портрете срезалась треть высоты, а
/// лёжа — две трети, и от картинки оставалась полоса. У пейзажей сюжет стоит
/// внизу, и центральная обрезка выбрасывала его целиком.
///
/// Теперь вариант берётся по пропорциям, а при обрезке в кадре держится точка
/// фокуса сюжета.
private struct FocusedPicture: View {
    let scene: VerseScene
    let size: CGSize

    var body: some View {
        let variant = SceneBackground.Variant.fitting(size)
        let frame = variant.filling(size, focus: scene.focus)
        Image("\(scene.asset)-\(variant.rawValue)", bundle: .module)
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }
}

extension SceneBackground.Variant {
    /// Ширина к высоте у файлов этого варианта.
    var aspect: CGFloat {
        switch self {
        case .tall: 1320.0 / 2868.0
        case .square: 1
        case .wide: 1092.0 / 510.0
        }
    }

    /// Вариант под экран.
    ///
    /// Портрет — всегда высокий, даже почти квадратный экран iPhone Duo. Он
    /// крупнее, 1320 пикселей по ширине против 1092 у квадратного: на
    /// внутреннем экране Duo квадратный пришлось бы растянуть в 2,6 раза, и
    /// картинка заметно поплыла бы. Срез трети высоты здесь меньшее зло, тем более что
    /// фокус держит сюжет в кадре. Лёжа — квадратный: высокий оставил бы
    /// узкую полосу.
    static func fitting(_ size: CGSize) -> Self {
        guard size.width > 0, size.height > 0 else { return .tall }
        let ratio = size.width / size.height
        if ratio < 0.85 { return .tall }
        if ratio < 1.6 { return .square }
        return .wide
    }

    /// Рамка картинки, заполняющей `size` без полей, со сдвигом, при котором
    /// `focus` оказывается как можно ближе к центру и края при этом не
    /// отходят от краёв экрана.
    func filling(_ size: CGSize, focus: UnitPoint) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let width: CGFloat
        let height: CGFloat
        if size.width / size.height > aspect {
            width = size.width
            height = size.width / aspect
        } else {
            height = size.height
            width = size.height * aspect
        }
        let x = min(0, max(size.width - width, size.width / 2 - focus.x * width))
        let y = min(0, max(size.height - height, size.height / 2 - focus.y * height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

extension VerseScene {
    /// Где на картинке сюжет. Эта точка остаётся в кадре, когда экран режет
    /// картинку.
    ///
    /// У Гималаев и храма сюжет стоит низко (гребни, силуэт), у дии — выше
    /// середины. Новый фон без точки фокуса не соберётся — здесь исчерпывающий
    /// перебор, а не значение по умолчанию. Те же точки использует
    /// `tools/art/build_assets.py`, когда режет квадрат и полосу.
    var focus: UnitPoint {
        switch self {
        case .himalaya: UnitPoint(x: 0.5, y: 0.8)
        case .ganga: UnitPoint(x: 0.5, y: 0.34)
        case .temple: UnitPoint(x: 0.5, y: 0.74)
        case .diya: UnitPoint(x: 0.5, y: 0.22)
        case .lotus: UnitPoint(x: 0.5, y: 0.8)
        case .rangoli: UnitPoint(x: 0.5, y: 0.5)
        case .mandala: UnitPoint(x: 0.5, y: 0.4)
        }
    }
}

/// Затемнение под строкой состояния и заголовком экрана.
///
/// Подложка под текстом сюда не достаёт — она начинается ниже, — а часы,
/// индикаторы и крупный заголовок лежат прямо на картинке. На светлых фонах
/// вроде «Пастыря» они об неё спотыкаются.
struct TopFade: View {
    let scene: VerseScene

    var body: some View {
        LinearGradient(
            stops: [.init(color: tint.opacity(0.38), location: 0),
                    .init(color: tint.opacity(0.16), location: 0.45),
                    .init(color: tint.opacity(0), location: 1)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 190)
        .allowsHitTesting(false)
    }

    private var tint: Color { scene.prefersLightText ? .black : .white }
}

/// Картинка фона с подложкой. Живёт здесь, а не в каждом месте показа: файлы
/// лежат в ресурсах этого модуля, и обратиться к ним из бандла виджета нельзя.
public struct SceneBackground: View {
    public enum Variant: String { case tall, wide, square }

    let scene: VerseScene
    let variant: Variant

    public init(scene: VerseScene, variant: Variant) {
        self.scene = scene
        self.variant = variant
    }

    public var body: some View {
        Image("\(scene.asset)-\(variant.rawValue)", bundle: .module)
            .resizable()
            .scaledToFill()
            .overlay { SceneScrim(scene: scene) }
    }
}

/// Затемнение или высветление под текстом.
///
/// Сплошная пелена читалась бы как «картинку испортили»: смысл фона в том,
/// чтобы его было видно. Поэтому подложка сгущается только в полосе, где лежат
/// ссылка, стих и плашка контекста, а к краям сходит почти на нет — лицо сверху
/// и одежда снизу остаются открытыми.
///
/// Плотность у каждого фона своя и посчитана от яркости самой картинки в этой
/// полосе: она доводит контраст до 4,5:1, ниже которого текст на светлом
/// участке перестаёт читаться.
public struct SceneScrim: View {
    let scene: VerseScene

    public init(scene: VerseScene) { self.scene = scene }

    public var body: some View {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    private var stops: [Gradient.Stop] {
        let band = VerseScene.textBand
        let fade = 0.13
        let tint: Color = scene.prefersLightText ? .black : .white
        // По краям подложка не нулевая: совсем без неё дата сверху и подпись
        // издания на пёстрых участках всё же теряются.
        let edge = scene.scrim * 0.18
        return [
            .init(color: tint.opacity(edge), location: 0),
            .init(color: tint.opacity(edge), location: max(0, band.lowerBound - fade)),
            .init(color: tint.opacity(scene.scrim), location: band.lowerBound),
            .init(color: tint.opacity(scene.scrim), location: band.upperBound),
            .init(color: tint.opacity(edge), location: min(1, band.upperBound + fade)),
            .init(color: tint.opacity(edge), location: 1),
        ]
    }
}
