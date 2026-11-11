import CoreGraphics
import DeepamCore
import SwiftUI
import Testing
@testable import DeepamUI

/// Фон-картинка на экранах разных пропорций.
///
/// Размеры экранов — в точках: обычный iPhone, и оба экрана iPhone Duo в
/// портрете и лёжа (внешний 1398×2034 px, внутренний 2007×2853 px при @3x).
@Suite("Фон под пропорции экрана")
struct BackgroundFitTests {
    private let iPhone = CGSize(width: 393, height: 852)
    private let duoOuter = CGSize(width: 466, height: 678)
    private let duoInner = CGSize(width: 669, height: 951)
    private let duoInnerLying = CGSize(width: 951, height: 669)

    /// Портрет — высокий вариант: он крупнее, и почти квадратный экран Duo
    /// его не размоет. Лёжа — квадратный: от высокого осталась бы полоса.
    @Test
    func `вариант выбирается по пропорциям`() {
        #expect(SceneBackground.Variant.fitting(iPhone) == .tall)
        #expect(SceneBackground.Variant.fitting(duoOuter) == .tall)
        #expect(SceneBackground.Variant.fitting(duoInner) == .tall)
        #expect(SceneBackground.Variant.fitting(duoInnerLying) == .square)
    }

    /// На обычном iPhone пропорции экрана и картинки совпадают: фокус ничего
    /// не сдвигает, и вид остаётся тем, что был до iPhone Duo.
    @Test
    func `на обычном iPhone картинка почти не режется`() {
        for scene in VerseScene.allCases {
            let frame = SceneBackground.Variant.tall.filling(iPhone, focus: scene.focus)
            #expect(abs(frame.minX) < 1, "\(scene.rawValue)")
            #expect(abs(frame.minY) < 2, "\(scene.rawValue)")
        }
    }

    /// Ни при каком фокусе под картинкой не должно открыться полей.
    @Test(arguments: [CGSize(width: 393, height: 852), CGSize(width: 466, height: 678),
                      CGSize(width: 669, height: 951), CGSize(width: 951, height: 669),
                      CGSize(width: 375, height: 667)])
    func `картинка закрывает весь экран`(size: CGSize) {
        for variant in [SceneBackground.Variant.tall, .square, .wide] {
            for focus in [UnitPoint.topLeading, .center, .bottomTrailing, UnitPoint(x: 0.5, y: 1)] {
                let frame = variant.filling(size, focus: focus)
                #expect(frame.minX <= 0.001)
                #expect(frame.minY <= 0.001)
                #expect(frame.maxX >= size.width - 0.001)
                #expect(frame.maxY >= size.height - 0.001)
            }
        }
    }

    /// У Гималаев и храма сюжет — гребни гор и силуэт у нижнего края картинки.
    /// При обрезке по центру на портретном Duo он уходил из кадра целиком.
    @Test
    func `пейзаж держит низ картинки`() {
        for scene in [VerseScene.himalaya, .temple] {
            for size in [duoOuter, duoInner] {
                let variant = SceneBackground.Variant.fitting(size)
                let frame = variant.filling(size, focus: scene.focus)
                #expect(abs(frame.maxY - size.height) < 0.001, "\(scene.rawValue) \(size)")
            }
        }
    }

    /// У Ганги и дии сюжет выше середины: точка фокуса обязана попадать в
    /// кадр на любом экране, как бы он ни резал картинку.
    @Test
    func `сюжет остаётся в кадре`() {
        for scene in VerseScene.allCases {
            for size in [iPhone, duoOuter, duoInner, duoInnerLying] {
                let variant = SceneBackground.Variant.fitting(size)
                let frame = variant.filling(size, focus: scene.focus)
                let top = -frame.minY / frame.height
                let bottom = (size.height - frame.minY) / frame.height
                #expect(top <= scene.focus.y && scene.focus.y <= bottom,
                        "\(scene.rawValue) \(size)")
            }
        }
    }
}
