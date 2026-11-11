import Foundation
import Testing
@testable import DeepamCore

@Suite("Обучающий тур")
@MainActor
struct CoachTests {

    private func make() throws -> (Coach, AppSettings) {
        let store = try #require(UserDefaults(suiteName: "coach.\(UUID().uuidString)"))
        let settings = AppSettings(store: store)
        return (Coach(settings: settings), settings)
    }

    @Test
    func `тур начинается со свайпа`() throws {
        let (coach, _) = try make()
        coach.startIfNeeded()
        #expect(coach.step == .swipe)
    }

    /// Подсветка поверх экрана, который человек уже знает, — помеха. Пройденный
    /// тур не должен возвращаться ни при запуске, ни после переустановки
    /// виджета: флаг живёт в настройках.
    @Test
    func `пройденный тур не запускается снова`() throws {
        let (coach, settings) = try make()
        coach.startIfNeeded()
        coach.finish()
        #expect(coach.step == nil)
        #expect(settings.hasSeenCoach)

        let second = Coach(settings: settings)
        second.startIfNeeded()
        #expect(second.step == nil)
    }

    /// Тур запускается по появлению вкладок, а появиться они могут не один раз.
    /// Без защиты повторный вызов отбросил бы человека на первый шаг посреди
    /// тура.
    @Test
    func `повторный запуск не сбрасывает идущий тур`() throws {
        let (coach, _) = try make()
        coach.startIfNeeded()
        coach.completed(.swipe)
        #expect(coach.step == .areas)

        coach.startIfNeeded()
        #expect(coach.step == .areas, "тур откатился на первый шаг")
    }

    /// Каждый шаг закрывается своим действием, а не любым. Иначе свайп на
    /// «Сегодня» проматывал бы и подсказку про «Места».
    @Test
    func `чужое действие шаг не закрывает`() throws {
        let (coach, _) = try make()
        coach.startIfNeeded()
        coach.completed(.markDone)
        #expect(coach.step == .swipe, "шаг закрылся действием из другого места")
        coach.completed(.swipe)
        #expect(coach.step == .areas)
    }

    @Test
    func `шаги идут по порядку и заканчиваются`() throws {
        let (coach, settings) = try make()
        coach.startIfNeeded()
        for expected in Coach.Step.allCases {
            #expect(coach.step == expected)
            coach.completed(expected)
        }
        #expect(coach.step == nil)
        #expect(settings.hasSeenCoach)
    }

    /// Переключение на виджеты — свой шаг, а не половина следующего: подсказка
    /// обязана смениться ровно в момент, когда человек сделал то, о чём его
    /// просили. И выбор оформления виджета до переключения не засчитывается —
    /// он относится к другой области.
    @Test
    func `оформление виджетов идёт через отдельный шаг переключения`() throws {
        let (coach, _) = try make()
        coach.startIfNeeded()
        coach.completed(.swipe)
        coach.advance()
        coach.completed(.appStyle)
        #expect(coach.step == .switchToWidgets)

        coach.completed(.widgetStyle)
        #expect(coach.step == .switchToWidgets, "выбор до переключения засчитался")
        coach.completed(.switchToWidgets)
        #expect(coach.step == .widgetStyle)
    }

    /// Вкладка выводится из шага: подсказка не имеет смысла, если указывает на
    /// то, чего сейчас на экране нет.
    @Test
    func `каждый шаг знает свою вкладку`() {
        #expect(Coach.Step.swipe.tab == "today")
        #expect(Coach.Step.appStyle.tab == "look")
        #expect(Coach.Step.markDone.tab == "places")
    }
}
