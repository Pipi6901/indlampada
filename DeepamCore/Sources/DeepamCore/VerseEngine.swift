import Foundation

/// Выдача стихов: какой показать сегодня и что показать при листании.
///
/// Движок ничего не хранит и ни от чего не зависит, кроме размера пула. Одни и
/// те же аргументы всегда дают один и тот же ответ, поэтому приложение, виджет
/// и расширение на экране блокировки считают одно и то же независимо друг от
/// друга — синхронизировать между ними нечего.
public struct VerseEngine: Sendable, Hashable {
    /// Сколько карточек в пуле. Меняется при смене темы состояния.
    public let poolCount: Int

    public init(poolCount: Int) {
        precondition(poolCount > 0, "пул не может быть пустым")
        self.poolCount = poolCount
    }

    // MARK: - Стих дня

    /// Номер дня, от которого пляшет вся выдача.
    ///
    /// Берётся порядковый номер дня в эре, а не расстояние от какой-нибудь даты
    /// запуска: так значение не зависит от часового пояса больше, чем на сутки,
    /// и не ломается при переводе часов.
    public static func dayIndex(
        for date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    /// Индекс стиха дня.
    public func dailyIndex(on day: Int) -> Int {
        var h = UInt64(bitPattern: Int64(day))
        h ^= h >> 33
        h = h &* 0xFF51_AFD7_ED55_8CCD
        h ^= h >> 33
        h = h &* 0xC4CE_B9FE_1A85_EC53
        h ^= h >> 33
        return Int(h % UInt64(poolCount))
    }

    // MARK: - Листание

    /// Перестановка порядка листания. Пересевается каждый день, и это не
    /// украшение: если бы листание шло по той же последовательности, что дни,
    /// один свайп вверх показывал бы завтрашний стих дня — и весь смысл
    /// «сегодняшнего слова» пропадал бы после первого же движения пальцем.
    private func browsePermutation(on day: Int) -> IndexPermutation {
        IndexPermutation(count: poolCount, seed: UInt64(bitPattern: Int64(day)))
    }

    /// Индекс карточки на смещении `offset` от стиха дня.
    ///
    /// `offset == 0` — сам стих дня, положительные значения листают вперёд,
    /// отрицательные назад. За `poolCount` шагов проходится весь пул без
    /// повторов, дальше начинается второй круг.
    public func index(offset: Int, on day: Int) -> Int {
        let permutation = browsePermutation(on: day)
        let daily = dailyIndex(on: day)
        let atZero = permutation(0)
        let candidate = permutation(offset)
        // Транспозиция: позиция 0 в листании обязана совпасть со стихом дня.
        // Меняем местами то, что перестановка кладёт в ноль, и сам стих дня —
        // биекция от этого остаётся биекцией.
        if candidate == daily { return atZero }
        if candidate == atZero { return daily }
        return candidate
    }

    /// Причины, по которым смещение сбрасывается в ноль.
    ///
    /// Собраны в одном месте, чтобы поведение нельзя было случайно разойтись
    /// между экранами: список из спеки, а не из привычек вызывающего кода.
    public enum Reset: Sendable, Hashable, CaseIterable {
        case newDay
        case coldStart
        case themeChanged
        case languageChanged
        case dateTapped
    }
}
