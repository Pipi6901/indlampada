import Testing
@testable import DeepamCore

@Suite("Перестановка индексов")
struct IndexPermutationTests {

    /// Главное свойство: если это не биекция, обещание «без повторов» ложно.
    @Test(arguments: [1, 2, 3, 7, 16, 17, 64, 100, 1003])
    func `накрывает всю область ровно один раз`(count: Int) {
        let permutation = IndexPermutation(count: count, seed: 42)
        let produced = Set((0..<count).map { permutation($0) })
        #expect(produced.count == count)
        #expect(produced == Set(0..<count))
    }

    /// Листание назад — тот же вызов с отрицательным аргументом, а не отдельная
    /// ветка кода. Проверяем, что нормализация не сдвигает результат.
    @Test
    func `отрицательные позиции продолжают тот же круг`() {
        let count = 1003
        let permutation = IndexPermutation(count: count, seed: 7)
        #expect(permutation(-1) == permutation(count - 1))
        #expect(permutation(-count) == permutation(0))
        #expect(permutation(-count - 5) == permutation(count - 5))
    }

    /// Приложение и расширение виджета считают перестановку независимо,
    /// поэтому одинаковое зерно обязано давать одинаковый результат.
    @Test
    func `одно зерно — одна и та же последовательность`() {
        let first = IndexPermutation(count: 500, seed: 12345)
        let second = IndexPermutation(count: 500, seed: 12345)
        #expect((0..<500).allSatisfy { first($0) == second($0) })
    }

    @Test
    func `разные зёрна дают разный порядок`() {
        let a = IndexPermutation(count: 1003, seed: 1)
        let b = IndexPermutation(count: 1003, seed: 2)
        let same = (0..<1003).count { a($0) == b($0) }
        // Совпадения по случайности допустимы, совпадение целиком — нет.
        #expect(same < 50)
    }

    /// Простая арифметическая перестановка тоже биекция, но шаг у неё
    /// постоянный, и на отсортированном по книгам пуле это видно глазом.
    @Test
    func `шаг между соседями не постоянен`() {
        let count = 1003
        let permutation = IndexPermutation(count: count, seed: 99)
        let steps = Set((0..<200).map { permutation($0 + 1) - permutation($0) })
        #expect(steps.count > 100)
    }
}
