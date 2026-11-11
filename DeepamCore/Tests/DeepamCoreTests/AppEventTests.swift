import Foundation
import Testing
@testable import DeepamCore

@Suite("События аналитики")
struct AppEventTests {

    private func makeStore() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "events.tests." + UUID().uuidString))
    }

    private let home = WidgetCensus.Slot(kind: "DeepamVerse", family: "systemSmall")
    private let lock = WidgetCensus.Slot(kind: "DeepamVerse", family: "accessoryRectangular")

    // MARK: - Перепись виджетов

    /// Обновившийся с прежней версии не должен разом «поставить» все свои
    /// давно стоящие виджеты.
    @Test
    func `первая перепись только запоминает`() throws {
        let census = WidgetCensus(store: try makeStore())
        #expect(census.update([home, lock]).isEmpty)
    }

    @Test
    func `поставленный и снятый виджет`() throws {
        let census = WidgetCensus(store: try makeStore())
        _ = census.update([home])

        #expect(census.update([home, lock]) == [
            .widgetAdded(kind: "DeepamVerse", family: "accessoryRectangular"),
        ])
        #expect(census.update([lock]) == [
            .widgetRemoved(kind: "DeepamVerse", family: "systemSmall"),
        ])
        #expect(census.update([lock]).isEmpty)
    }

    /// Два одинаковых виджета — два, а не один: второй малый на рабочем столе
    /// тоже поставили руками.
    @Test
    func `экземпляры считаются поштучно`() throws {
        let census = WidgetCensus(store: try makeStore())
        _ = census.update([])

        let added = census.update([home, home])
        #expect(added.count == 2)
        #expect(census.update([home]) == [.widgetRemoved(kind: "DeepamVerse", family: "systemSmall")])
    }

    /// Пустой список после переписи — тоже знание: всё сняли.
    @Test
    func `сняли всё`() throws {
        let census = WidgetCensus(store: try makeStore())
        _ = census.update([home, lock])
        #expect(census.update([]).count == 2)
    }

    // MARK: - Параметры

    /// GA4 считает доход только по числу и валюте — без них покупка в отчёте
    /// о доходе не появится.
    @Test
    func `покупка несёт сумму числом`() {
        let event = AppEvent.purchase(.year, productID: "com.astonio.deepam.yearly",
                                      price: Decimal(string: "24.99")!, currency: "USD")
        #expect(event.name == "purchase")
        // Decimal в Double переводится не бит в бит, поэтому сравнение с допуском.
        guard case let .double(value)? = event.parameters["value"] else {
            Issue.record("сумма не числом")
            return
        }
        #expect(abs(value - 24.99) < 0.000_1)
        #expect(event.parameters["currency"] == .text("USD"))
        #expect(event.parameters["plan"] == .text("year"))
    }

    /// Вариант пейволла уходит параметром, только когда он есть: у скидки
    /// после пейволла вариантов нет, и пустое значение засоряло бы отчёт.
    @Test
    func `вариант пейволла`() {
        let branch = AppEvent.paywallView(.onboarding, variant: "beauty")
        #expect(branch.parameters["variant"] == .text("beauty"))
        #expect(branch.parameters["source"] == .text("onboarding"))
        #expect(AppEvent.paywallView(.welcome).parameters["variant"] == nil)
    }

    /// Ограничения GA4: имя до 40 символов, буквы, цифры и подчёркивание,
    /// начинается с буквы. Нарушение SDK не роняет — событие молча теряется.
    @Test
    func `имена годятся для GA4`() {
        let events: [AppEvent] = [
            .onboardingStep(index: 0, name: "verse"), .onboardingComplete,
            .paywallView(.standBy), .paywallView(.onboarding, variant: "comfort"),
            .trialStart(.year, productID: "x"),
            .purchase(.week, productID: "x", price: 1, currency: nil),
            .purchaseFailed(.month, reason: "x"),
            .widgetAdded(kind: "x", family: "x"), .widgetRemoved(kind: "x", family: "x"),
            .pushPermission(granted: true, source: "onboarding"), .pushOpened(.dailyVerse),
            .onboardingAnswer(question: "theme", answer: "x"),
            .cancelReason(reason: "price", source: "sheet", wasTrial: true),
            .reviewPrompt(source: "auto"),
            .campaignOpened("easter_2027"),
            .whatsNewStep(index: 0, name: "icons"), .promoOptIn(on: true, source: "places"),
        ]
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        for event in events {
            #expect(event.name.count <= 40, "\(event.name)")
            #expect(event.name.first?.isLetter == true, "\(event.name)")
            #expect(event.name.allSatisfy(allowed.contains), "\(event.name)")
            #expect(!event.name.hasPrefix("firebase_") && !event.name.hasPrefix("ga_"))
            // Имена, которые Firebase пишет сам и чужие с такими же отбрасывает.
            #expect(!["notification_open", "notification_receive", "app_open", "first_open"]
                .contains(event.name), "\(event.name)")
        }
    }
}
