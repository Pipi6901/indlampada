/// Псевдослучайная перестановка индексов `0..<count`.
///
/// Сеть Фейстеля с обходом лишнего диапазона — приём из шифрования с сохранением
/// формата. Нужна она затем, что листание стихов обязано быть одновременно
/// случайным на вид, обратимым и без повторов, а таблицу на тысячу элементов
/// держать в памяти и синхронизировать между приложением и расширениями виджета
/// не хочется. Перестановка считается за наносекунды и не хранит ничего.
///
/// Свойства, на которые опирается движок:
/// - это биекция, поэтому каждый индекс встретится ровно один раз за круг;
/// - обратный ход стоит столько же, сколько прямой: `perm(k - 1)`;
/// - зацикливание получается само, отрицательные индексы допустимы.
public struct IndexPermutation: Sendable, Hashable {
    public let count: Int
    private let seed: UInt64
    private let halfBits: UInt32
    private let mask: UInt32

    /// - Parameters:
    ///   - count: размер области. Должен быть положительным.
    ///   - seed: зерно. Одно и то же зерно всегда даёт одну и ту же перестановку.
    public init(count: Int, seed: UInt64) {
        precondition(count > 0, "перестановка требует непустой области")
        self.count = count
        self.seed = seed
        var bits: UInt32 = 1
        while (1 << bits) < count { bits += 1 }
        self.halfBits = (bits + 1) / 2
        self.mask = (1 << self.halfBits) - 1
    }

    /// Раундовая функция. Качество перемешивания важнее криптостойкости:
    /// здесь нечего защищать, нужна только неразличимая на глаз последовательность.
    private func round(_ value: UInt32, _ number: UInt32) -> UInt32 {
        var h = UInt64(value) &+ seed &+ UInt64(number) &* 0x9E37_79B9_7F4A_7C15
        h ^= h >> 30
        h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 27
        h = h &* 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return UInt32(truncatingIfNeeded: h) & mask
    }

    /// Индекс на позиции `index`. Отрицательные значения нормализуются, так что
    /// листание назад работает тем же вызовом.
    public func callAsFunction(_ index: Int) -> Int {
        var value = UInt32(((index % count) + count) % count)
        // Обход лишнего: сеть определена на 2^(2·halfBits) ≥ count, и всё, что
        // выпало за границу, прогоняется ещё раз. Цикл конечен, потому что сеть —
        // перестановка на своей области, а значит рано или поздно попадёт внутрь.
        repeat {
            var left = value >> halfBits
            var right = value & mask
            for number: UInt32 in 0..<4 {
                let next = left ^ round(right, number)
                left = right
                right = next
            }
            value = (left << halfBits) | right
        } while Int(value) >= count
        return Int(value)
    }
}
