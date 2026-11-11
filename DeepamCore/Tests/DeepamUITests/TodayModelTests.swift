import Foundation
import DeepamCore
import Testing
@testable import DeepamUI

@Suite("Экран «Сегодня»")
struct TodayModelTests {
    let day = 739_500

    private func makeModel(_ locale: AppLocale = .en) throws -> TodayModel {
        TodayModel(corpus: try Corpus.load(locale), day: day)
    }

    @Test
    func `на старте показан стих дня`() throws {
        let model = try makeModel()
        #expect(model.offset == 0)
        #expect(!model.isBrowsing)
        #expect(model.depth == 0)
    }

    @Test
    func `свайп вверх и вниз двигают смещение в разные стороны`() throws {
        let model = try makeModel()
        let daily = model.card.id
        model.showNext()
        #expect(model.offset == 1)
        #expect(model.card.id != daily)
        model.showPrevious()
        #expect(model.offset == 0)
        #expect(model.card.id == daily)
    }

    /// Ради этого блок с датой и получил второе состояние: пролистав далеко,
    /// человек должен одним нажатием оказаться там, где начал.
    @Test
    func `тап по дате возвращает к стиху дня с любой глубины`() throws {
        let model = try makeModel()
        let daily = model.card.id
        for _ in 1...37 { model.showNext() }
        #expect(model.depth == 37)
        #expect(model.isBrowsing)
        model.returnToDaily()
        #expect(model.offset == 0)
        #expect(model.card.id == daily)
    }

    @Test
    func `листание назад тоже считается листанием`() throws {
        let model = try makeModel()
        model.showPrevious()
        #expect(model.isBrowsing)
        #expect(model.depth == 1)
        #expect(model.offset == -1)
    }

    @Test
    func `у каждой карточки при листании есть контекст`() throws {
        let model = try makeModel()
        for _ in 1...50 {
            #expect(model.context?.isEmpty == false, "нет контекста у \(model.card.id)")
            model.showNext()
        }
    }

    @Test
    func `новый день сбрасывает смещение и меняет стих`() throws {
        let model = try makeModel()
        model.showNext()
        model.showNext()
        let before = model.card.id
        model.refresh(day: day + 1)
        #expect(model.offset == 0)
        #expect(model.card.id != before)
    }

    @Test
    func `тот же день ничего не сбрасывает`() throws {
        let model = try makeModel()
        model.showNext()
        model.refresh(day: day)
        #expect(model.offset == 1)
    }

    /// Смена языка не должна сбивать человека с той карточки, на которую он
    /// смотрит: состав и порядок пула во всех языках одинаковы.
    @Test
    func `смена языка сохраняет отрывок`() throws {
        let model = try makeModel(.en)
        let passage = model.card.passage
        model.switchLanguage(to: try Corpus.load(.en))
        #expect(model.offset == 0)
        #expect(model.card.passage == passage)
        #expect(model.corpus.lang == "en")
    }

    @Test
    func `фильтр по темам сужает пул и сбрасывает смещение`() throws {
        let model = try makeModel()
        model.showNext()
        let theme = try #require(model.corpus.themes.sorted().first)
        model.themes = [theme]
        #expect(model.offset == 0)
        #expect(model.card.theme == theme)
        // Внутри темы листание работает так же и остаётся внутри неё.
        for _ in 1...30 {
            model.showNext()
            #expect(model.card.theme == theme)
        }
    }

    @Test
    func `снятие фильтра возвращает полный пул`() throws {
        let model = try makeModel()
        model.themes = [try #require(model.corpus.themes.sorted().first)]
        let narrowed = model.pool.count
        model.themes = []
        #expect(model.pool.count == model.corpus.cards.count)
        #expect(narrowed < model.pool.count)
    }

    @Test
    func `полный круг по пулу не повторяется`() throws {
        let model = try makeModel()
        var seen = Set<String>()
        for _ in 0..<model.pool.count {
            seen.insert(model.card.id)
            model.showNext()
        }
        #expect(seen.count == model.pool.count)
        // Круг замкнулся ровно там, где начался.
        #expect(model.offset == model.pool.count)
        let fresh = try makeModel()
        #expect(model.card.id == fresh.card.id)
    }
}
