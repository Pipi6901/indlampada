import Foundation
import Testing
@testable import DeepamCore

@Suite("Текст для экрана блокировки")
struct ShortTextTests {

    /// Короткий стих трогать нечего — он и так помещается.
    @Test
    func `короткий текст остаётся как есть`() {
        let text = "Иисус прослезился."
        #expect(Card.shorten(text) == text)
    }

    /// Ради этого всё и делается: система обрезала бы посреди слова, и на
    /// карточке-продолжении выходил бы набор слов.
    @Test
    func `длинный обрывается по границе слова`() {
        let long = String(repeating: "слово ", count: 40)
        let short = Card.shorten(long)
        #expect(short.count < long.count)
        #expect(short.hasSuffix("…"))
        // Между последним словом и многоточием не должно остаться обрубка.
        let body = short.dropLast()
        #expect(!body.hasSuffix(" "), "лишний пробел перед многоточием")
        #expect(body.split(separator: " ").allSatisfy { $0 == "слово" },
                "слово разрезано пополам: \(short)")
    }

    /// Если в пределах лимита есть конец предложения — режем по нему, и обрыв
    /// не виден вовсе.
    @Test
    func `предпочитает конец предложения`() {
        let text = "Господь — Пастырь мой; я ни в чем не буду нуждаться. "
            + String(repeating: "и ещё много слов ", count: 10)
        let short = Card.shorten(text)
        #expect(short.hasSuffix("."))
        #expect(!short.contains("…"))
    }

    /// Обрыв в самом начале хуже, чем многоточие: одно слово вместо стиха
    /// ничего не сообщает. Точка в первой трети не должна становиться концом.
    @Test
    func `ранняя точка не обрывает стих`() {
        let text = "Он. " + String(repeating: "продолжение фразы ", count: 12)
        #expect(Card.shorten(text) != "Он.")
    }
}
