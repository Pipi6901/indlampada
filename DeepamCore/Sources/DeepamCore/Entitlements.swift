import Foundation
import Observation

/// Доступ к платному. Один флаг, потому что и подписка одна.
///
/// Протокол нужен затем, что реальная реализация приедет из RevenueCat, а до
/// неё интерфейс и тесты должны работать: экраны обращаются к абстракции и не
/// знают, кто её выполняет.
public protocol EntitlementStore: AnyObject, Observable {
    var isSubscribed: Bool { get }

    /// Снимок подписки для тех, кто её сам не видит: виджета и отката
    /// оформления. `nil` — ответа ещё не было, и решать по нему ничего нельзя.
    var proStatus: ProStatus? { get }
}

extension EntitlementStore {
    /// Заглушке снимок не нужен: без RevenueCat откатывать нечего.
    public var proStatus: ProStatus? { nil }

    public func isUnlocked(_ surface: Surface) -> Bool {
        isSubscribed || !surface.isPremium
    }

    public func isUnlocked(_ style: VerseStyle) -> Bool {
        isSubscribed || !style.isPremium
    }

    public func isUnlocked(_ scene: VerseScene) -> Bool {
        isSubscribed || !scene.isPremium
    }

    public func isUnlocked(_ icon: AppIcon) -> Bool {
        isSubscribed || !icon.isPremium
    }

    public func isUnlocked(_ font: VerseFont) -> Bool {
        isSubscribed || !font.isPremium
    }
}

/// Заглушка до подключения RevenueCat. Значение задаётся вручную — этого
/// хватает, чтобы прогнать оба состояния интерфейса в тестах и на симуляторе.
@Observable
public final class StubEntitlements: EntitlementStore {
    public var isSubscribed: Bool

    public init(isSubscribed: Bool = false) {
        self.isSubscribed = isSubscribed
    }
}
