import Foundation
import Testing
@testable import DeepamCore

@Suite("«Что нового» и согласие на новости")
struct WhatsNewTests {
    private func makeSettings() throws -> AppSettings {
        AppSettings(store: try #require(UserDefaults(suiteName: "whatsnew.\(UUID().uuidString)")))
    }

    /// Экран — только тем, кто прошёл онбординг раньше. Новый человек ещё в
    /// онбординге, и тот сам покажет всё новое.
    @Test
    func `экран ждёт тех, кто обновился`() throws {
        let settings = try makeSettings()
        #expect(!WhatsNew.isDue(settings))
        settings.hasSeenOnboarding = true
        #expect(WhatsNew.isDue(settings))
        settings.whatsNewSeen = WhatsNew.version
        #expect(!WhatsNew.isDue(settings))
    }

    /// Показанный экран и согласие переживают перезапуск: второй раз экран
    /// не появляется, а рассылки не начинают приходить тому, кто отписался.
    @Test
    func `отметка и согласие сохраняются`() throws {
        let store = try #require(UserDefaults(suiteName: "whatsnew.\(UUID().uuidString)"))
        let first = AppSettings(store: store)
        #expect(!first.promoOptIn)
        first.whatsNewSeen = WhatsNew.version
        first.promoOptIn = true

        let second = AppSettings(store: store)
        #expect(second.whatsNewSeen == WhatsNew.version)
        #expect(second.promoOptIn)
    }

    @Test
    func `события экрана и согласия`() {
        let step = AppEvent.whatsNewStep(index: 2, name: "daily")
        #expect(step.name == "whats_new_step")
        #expect(step.parameters["step_name"] == .text("daily"))
        let optIn = AppEvent.promoOptIn(on: true, source: "places")
        #expect(optIn.name == "promo_optin")
        #expect(optIn.parameters["granted"] == .int(1))
        #expect(PaywallSource.whatsNew.rawValue == "whats_new")
    }
}
