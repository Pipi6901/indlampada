import Foundation
import Testing
@testable import DeepamCore

@Suite("Пауза перед лентой")
@MainActor
struct PauseSessionTests {

    private func makeSession() throws -> PauseSession {
        let name = "pause.tests." + UUID().uuidString
        let store = try #require(UserDefaults(suiteName: name))
        return PauseSession(store: store)
    }

    /// Действие обязано возвращаться немедленно. Раньше оно висело, пока
    /// человек не нажмёт «Продолжить», — и «Команды» убивали его по таймауту с
    /// ошибкой «Сбой автоматизации».
    @Test
    func `показ не задерживает действие`() throws {
        let session = try makeSession()
        session.begin()
        #expect(session.isShowing)
    }

    /// Свернул соцсеть и тут же открыл снова — вторая пауза подряд лишняя, стих
    /// человек только что видел. Окно тишины заодно страхует и от петли на тех
    /// iOS, где программное открытие соцсети поднимает автоматизацию.
    @Test
    func `сразу после паузы она не показывается снова`() throws {
        let session = try makeSession()
        session.begin()
        session.finish()

        session.begin()
        #expect(!session.isShowing, "вторая пауза подряд лишняя")
    }

    /// Свернул приложение мимо кнопки — стих всё равно увидел. Не засчитать
    /// уход значило бы встретить его паузой снова при первом же возврате.
    @Test
    func `уход мимо кнопки засчитывается`() throws {
        let session = try makeSession()
        session.begin()
        session.finish()
        #expect(session.isWithinGrace)
    }

    /// Куда возвращаться, знает намерение: соцсеть выбирают параметром
    /// действия. Адрес доживает до кнопки и отдаётся ровно один раз.
    @Test
    func `адрес возврата доживает до кнопки`() throws {
        let session = try makeSession()
        let instagram = try #require(URL(string: "instagram://"))

        session.begin(returnTo: instagram)
        #expect(session.finish() == instagram)
        #expect(session.finish() == nil, "закрытая пауза не должна отдавать адрес второй раз")
    }

    /// Автоматизации, собранные по прежней схеме, параметра не передают.
    /// Паузу это ломать не должно — просто возвращать некуда.
    @Test
    func `без адреса пауза всё равно показывается`() throws {
        let session = try makeSession()
        session.begin()
        #expect(session.isShowing)
        #expect(session.finish() == nil)
    }

    /// Окно тишины не должно затягиваться: через сутки пауза обязана
    /// показываться как ни в чём не бывало.
    @Test
    func `по истечении окна пауза показывается снова`() throws {
        let name = "pause.tests." + UUID().uuidString
        let store = try #require(UserDefaults(suiteName: name))
        store.set(Date.now.timeIntervalSince1970 - PauseSession.grace - 1,
                  forKey: "pause.lastPassed")
        let session = PauseSession(store: store)
        #expect(!session.isWithinGrace)

        session.begin()
        #expect(session.isShowing)
    }

    /// В окне тишины приложение всё равно поднимается — `openAppWhenRun`
    /// статическое. Показывать нечего, значит надо вернуть человека в соцсеть,
    /// иначе он остаётся в Deepam без стиха, как и было на устройстве.
    @Test
    func `в окне тишины пауза не показывается, а отскакивает в соцсеть`() throws {
        let session = try makeSession()
        let instagram = try #require(URL(string: "instagram://"))
        session.begin(returnTo: instagram)
        _ = session.finish()

        session.begin(returnTo: instagram)
        #expect(!session.isShowing)
        #expect(session.consumeBounce() == instagram)
        #expect(session.consumeBounce() == nil, "адрес отдаётся один раз")

        // Второй отскок сразу за первым не делается: иначе на iOS, где
        // программное открытие поднимает автоматизацию, вышел бы пинг-понг.
        session.begin(returnTo: instagram)
        #expect(session.bounceURL == nil)
    }

    /// Отметку о пройденной паузе ставит приложение, а прочитать её однажды
    /// захочет расширение — виджет или кнопка в Пункте управления — из своего
    /// процесса. Проверяется, что два объекта над одним хранилищем видят одно и
    /// то же: так и устроена пара «приложение — расширение».
    @Test
    func `окно тишины видно из другого процесса`() throws {
        let name = "pause.tests." + UUID().uuidString
        let store = try #require(UserDefaults(suiteName: name))

        let inApp = PauseSession(store: store)
        inApp.begin(returnTo: URL(string: "instagram://"))
        _ = inApp.finish()

        let inExtension = PauseSession(store: store)
        #expect(inExtension.isWithinGrace)
    }
}
