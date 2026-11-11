import Foundation
import Testing
@testable import DeepamCore

@Suite("Движок выдачи")
struct VerseEngineTests {
    let engine = VerseEngine(poolCount: 1003)
    let day = 739_500          // произвольный, но фиксированный день

    @Test(arguments: [0, 1, 2, 365, 739_500, 800_000])
    func `нулевое смещение — это стих дня`(day: Int) {
        let engine = VerseEngine(poolCount: 1003)
        #expect(engine.index(offset: 0, on: day) == engine.dailyIndex(on: day))
    }

    /// Обещание «без повторов» проверяется буквально: круг длиной в пул.
    @Test
    func `полный круг проходит пул без повторов`() {
        let seen = Set((0..<engine.poolCount).map { engine.index(offset: $0, on: day) })
        #expect(seen.count == engine.poolCount)
    }

    @Test
    func `после полного круга последовательность повторяется`() {
        #expect(engine.index(offset: engine.poolCount, on: day)
                == engine.index(offset: 0, on: day))
        #expect(engine.index(offset: engine.poolCount + 7, on: day)
                == engine.index(offset: 7, on: day))
    }

    /// Пролистать вперёд и вернуться назад тем же числом свайпов — значит
    /// увидеть ровно те же карточки в обратном порядке и оказаться на исходной.
    @Test
    func `свайп вперёд и назад возвращает туда же`() {
        var position = 0
        var forward: [Int] = []
        for _ in 1...12 {
            position += 1
            forward.append(engine.index(offset: position, on: day))
        }
        var backward: [Int] = []
        for _ in 1...12 {
            backward.append(engine.index(offset: position, on: day))
            position -= 1
        }
        #expect(backward == forward.reversed())
        #expect(position == 0)
        #expect(engine.index(offset: position, on: day) == engine.dailyIndex(on: day))
        #expect(engine.index(offset: -1, on: day) != engine.index(offset: 1, on: day))
    }

    /// Ловушка, ради которой перестановка листания вообще отделена от дневной.
    /// Наивная реализация `perm(день + k)` провалит этот тест на всех днях:
    /// один свайп вверх показывал бы завтрашний стих дня.
    @Test
    func `свайп вперёд не показывает завтрашний стих дня`() {
        let days = 500
        let leaks = (day..<(day + days)).count { d in
            engine.index(offset: 1, on: d) == engine.dailyIndex(on: d + 1)
        }
        // Случайные совпадения возможны — их ожидается около одного на пул.
        #expect(leaks < 10, "листание идёт по дневной последовательности")
    }

    @Test
    func `порядок листания меняется каждый день`() {
        let today = (1...20).map { engine.index(offset: $0, on: day) }
        let tomorrow = (1...20).map { engine.index(offset: $0, on: day + 1) }
        #expect(today != tomorrow)
    }

    @Test
    func `стих дня детерминирован и не зависит от объекта`() {
        let other = VerseEngine(poolCount: 1003)
        #expect((0..<1000).allSatisfy { engine.dailyIndex(on: $0) == other.dailyIndex(on: $0) })
    }

    @Test
    func `стих дня разный в соседние дни`() {
        let repeats = (day..<(day + 365)).count { engine.dailyIndex(on: $0) == engine.dailyIndex(on: $0 + 1) }
        #expect(repeats == 0)
    }

    @Test(arguments: [1, 2, 17, 1003])
    func `индекс всегда внутри пула`(count: Int) {
        let engine = VerseEngine(poolCount: count)
        for k in -50...50 {
            let i = engine.index(offset: k, on: 739_500)
            #expect(i >= 0 && i < count)
        }
    }

    @Test
    func `номер дня растёт на единицу в сутки`() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = DateComponents(calendar: calendar, year: 2026, month: 8, day: 31).date!
        let next = start.addingTimeInterval(24 * 60 * 60)
        #expect(VerseEngine.dayIndex(for: next, calendar: calendar)
                == VerseEngine.dayIndex(for: start, calendar: calendar) + 1)
    }
}
