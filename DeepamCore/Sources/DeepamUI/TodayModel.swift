import Foundation
import DeepamCore
import Observation

/// Состояние экрана «Сегодня».
///
/// Хранит ровно одно число — смещение от стиха дня. Всё остальное считается
/// движком на лету, поэтому состояние нечего терять, нечего синхронизировать и
/// нечему разъезжаться между экраном, виджетом и шерингом.
@Observable
public final class TodayModel {
    /// Смещение от стиха дня. Ноль — сам стих дня.
    public private(set) var offset: Int = 0

    /// Темы состояний. Смена набора сужает пул, поэтому старое смещение
    /// теряет смысл и сбрасывается.
    public var themes: Set<String> = [] {
        didSet {
            guard themes != oldValue else { return }
            rebuildPool()
            reset(.themeChanged)
        }
    }

    public private(set) var corpus: Corpus
    public private(set) var day: Int
    private(set) var pool: [Card]
    private var engine: VerseEngine

    public init(corpus: Corpus, day: Int = VerseEngine.dayIndex(for: .now)) {
        self.corpus = corpus
        self.day = day
        self.pool = corpus.cards
        self.engine = VerseEngine(poolCount: max(corpus.cards.count, 1))
    }

    // MARK: - Что показывать

    /// Карточка на текущем смещении.
    public var card: Card {
        pool[engine.index(offset: offset, on: day)]
    }

    /// Строка контекста для текущей карточки.
    public var context: String? {
        corpus.context(for: card)
    }

    /// Листает ли человек прямо сейчас. От этого зависит вид блока с датой:
    /// при нуле это обычная дата, иначе — кнопка возврата.
    public var isBrowsing: Bool { offset != 0 }

    /// Насколько далеко ушли от стиха дня. Нужно аналитике и подписи возврата.
    public var depth: Int { abs(offset) }

    // MARK: - Листание

    /// Свайп снизу вверх.
    public func showNext() { offset += 1 }

    /// Свайп сверху вниз.
    public func showPrevious() { offset -= 1 }

    /// Тап по блоку с датой.
    public func returnToDaily() { reset(.dateTapped) }

    /// Сбрасывает смещение. Причина не влияет на результат и существует затем,
    /// чтобы её можно было отправить в аналитику и увидеть в отладке.
    public func reset(_ reason: VerseEngine.Reset) {
        offset = 0
    }

    // MARK: - Внешние изменения

    /// Наступил новый день. Вызывается при возврате приложения из фона.
    public func refresh(day newDay: Int) {
        guard newDay != day else { return }
        day = newDay
        reset(.newDay)
    }

    /// Сменился язык: корпус другой, но состав и порядок карточек тот же.
    public func switchLanguage(to corpus: Corpus) {
        self.corpus = corpus
        rebuildPool()
        reset(.languageChanged)
    }

    private func rebuildPool() {
        pool = corpus.cards(themes: themes)
        engine = VerseEngine(poolCount: max(pool.count, 1))
    }
}
