import Foundation
import Testing
@testable import DeepamCore

@Suite("Намерения и подсветка платного")
struct IntentTests {

    /// У каждой плитки платного набора есть подпись: пустая плашка в сетке
    /// выглядит как недогрузившаяся картинка.
    @Test(arguments: AppLocale.allCases)
    func `у каждой плитки набора есть подпись`(locale: AppLocale) {
        let l10n = L10n(locale)
        for unlock in PaywallUnlock.allCases {
            #expect(!l10n[unlock.titleKey].isEmpty, "\(unlock.rawValue)")
        }
    }

    /// Пейволл обязан продавать только то, что без подписки закрыто.
    ///
    /// В сетке когда-то стояли «Все темы», хотя состояния `EntitlementStore`
    /// не проверяет вовсе и они бесплатны для всех: подписка их не открывала,
    /// потому что открывать было нечего. Тест держит список плиток привязанным
    /// к правам, а не к тому, что красиво ложится в шесть клеток.
    @Test
    func `каждая плитка набора закрыта без подписки`() {
        let free = StubEntitlements(isSubscribed: false)
        for unlock in PaywallUnlock.allCases {
            let locked = switch unlock {
            case .standBy: !free.isUnlocked(Surface.standBy)
            case .wallpaper: !free.isUnlocked(Surface.wallpaper)
            case .sets: VerseStyle.allCases.contains { !free.isUnlocked($0) }
            case .pictures: VerseScene.allCases.contains { !free.isUnlocked($0) }
            case .fonts: VerseFont.allCases.contains { !free.isUnlocked($0) }
            case .icons: AppIcon.allCases.contains { !free.isUnlocked($0) }
            }
            #expect(locked, "\(unlock.rawValue)")
        }
    }

    /// У каждого ответа есть подпись и пояснение: без второго строка в списке
    /// выглядела бы недописанной.
    @Test(arguments: AppLocale.allCases)
    func `у каждой цели есть обе подписи`(locale: AppLocale) {
        let l10n = L10n(locale)
        for goal in OnboardingGoal.allCases {
            #expect(!l10n[goal.titleKey].isEmpty, "\(goal.rawValue)")
            #expect(!l10n[goal.subKey].isEmpty, "\(goal.rawValue)")
        }
    }

    /// Порядок плиток у ветки — перестановка всего набора: ни одна плитка не
    /// пропала и не задвоилась, иначе сетка два на три поехала бы.
    @Test(arguments: OnboardingGoal.allCases)
    func `ветка показывает все шесть плиток`(goal: OnboardingGoal) {
        #expect(goal.unlocks.count == PaywallUnlock.allCases.count)
        #expect(Set(goal.unlocks) == Set(PaywallUnlock.allCases))
    }

    /// Ответ переживает перезапуск: пейволл показывается и позже, с замков, и
    /// должен говорить с человеком теми же словами.
    @Test
    func `цель сохраняется`() throws {
        let store = try #require(UserDefaults(suiteName: "goal.\(UUID().uuidString)"))
        let first = AppSettings(store: store)
        #expect(first.goal == nil)
        first.goal = .feed

        let second = AppSettings(store: store)
        #expect(second.goal == .feed)
    }

    /// «≈ 45 дней в году» в макете — это 2–4 часа: три часа в день за год.
    /// Округление вниз, чтобы цифра не выходила больше настоящей.
    @Test
    func `дни в году по часам в ленте`() {
        #expect(FeedHours.twoToFour.daysPerYear == 45)
        #expect(FeedHours.underOne.daysPerYear == 7)
        #expect(FeedHours.oneToTwo.daysPerYear == 22)
        #expect(FeedHours.overFour.daysPerYear == 76)
    }
}
