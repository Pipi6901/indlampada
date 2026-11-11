import Foundation
import Testing
@testable import DeepamCore

@Suite("Действия рассылки")
struct PushActionTests {

    /// Своё напоминание: только поверхность, и это не кампания.
    @Test
    func `своё напоминание не считается рассылкой`() {
        let action = PushAction(userInfo: ["surface": "homeScreen"])
        #expect(action.surface == .homeScreen)
        #expect(action.campaign == nil)
        #expect(!action.paywall)
    }

    /// Рассылка из консоли: Firebase кладёт имя кампании в `google.c.a.c_l`.
    @Test
    func `рассылка с вкладкой и пейволлом`() {
        let action = PushAction(userInfo: [
            "google.c.a.c_id": "123",
            "google.c.a.c_l": "easter_2027",
            "tab": "look",
            "paywall": "1",
        ])
        #expect(action.campaign == "easter_2027")
        #expect(action.tab == "look")
        #expect(action.paywall)
        #expect(action.offering == nil)
    }

    /// Предложение само по себе открывает пейволл: писать ещё и `paywall`
    /// в кампании не обязательно.
    @Test
    func `предложение открывает пейволл`() {
        let action = PushAction(userInfo: ["gcm.message_id": "m", "offering": "black_friday"])
        #expect(action.paywall)
        #expect(action.offering == "black_friday")
        #expect(action.campaign == "campaign")
    }

    /// Поле в консоли стёрли — пришла пустая строка. Это не команда.
    @Test
    func `пустые и выключенные значения пропускаются`() {
        let action = PushAction(userInfo: ["paywall": "0", "offering": "  ", "surface": "nowhere", "tab": ""])
        #expect(!action.paywall)
        #expect(action.offering == nil)
        #expect(action.surface == nil)
        #expect(action.tab == nil)
    }
}
