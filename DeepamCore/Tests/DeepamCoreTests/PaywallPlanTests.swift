import Foundation
import Testing
@testable import DeepamCore

@Suite("Платный экран: тарифы и триал")
struct PaywallPlanTests {

    /// Решение от 10.11.2026: триал на всех тарифах, у недельного и месячного 3 дня,
    /// у годового 7. В заглушке (без сети и без RevenueCat) экран показывает то же.
    @Test
    func `у каждого тарифа свой срок триала`() {
        let days = PaywallPlan.placeholder.map { $0.trialDays }
        #expect(days == [3, 3, 7])
        let all = PaywallPlan.placeholder.allSatisfy { $0.hasTrial }
        #expect(all)
    }

    @Test
    func `кнопка и подпись называют срок триала именно этого тарифа`() {
        let en = L10n(.en)
        let week = PaywallPlan(period: .week, price: "$1.99", trialDays: 3)
        let year = PaywallPlan(period: .year, price: "$14.99", trialDays: 7)
        #expect(week.callToAction(en) == "Start 3 days free")
        #expect(year.callToAction(en) == "Start 7 days free")
        #expect(week.note(en) == "3 days free")
        #expect(year.note(en) == "7 days free")
        #expect(week.priceWithPeriod(en) == "$1.99 per week")
        #expect(year.priceWithPeriod(en) == "$14.99 per year")

    }

    @Test
    func `без триала кнопка называет цену, а подпись период`() {
        let plan = PaywallPlan(period: .month, price: "$3.99")
        #expect(!plan.hasTrial)
        #expect(plan.callToAction(L10n(.en)) == "Subscribe for $3.99")
        #expect(plan.note(L10n(.en)) == "per month")
    }

    @Test
    func `отрицательный срок считается отсутствием триала`() {
        let plan = PaywallPlan(period: .week, price: "$1.99", trialDays: -2)
        #expect(plan.trialDays == 0)
        #expect(!plan.hasTrial)
    }

    @Test(arguments: AppLocale.allCases)
    func `на каждом языке в надпись подставляется срок`(locale: AppLocale) {
        let l10n = L10n(locale)
        for plan in PaywallPlan.placeholder {
            let cta = plan.callToAction(l10n)
            let note = plan.note(l10n)
            #expect(!cta.contains("%"), "\(locale.rawValue) \(plan.period): \(cta)")
            #expect(!note.contains("%"), "\(locale.rawValue) \(plan.period): \(note)")
            #expect(cta.contains("\(plan.trialDays)"), "\(locale.rawValue): \(cta)")
            #expect(note.contains("\(plan.trialDays)"), "\(locale.rawValue): \(note)")
        }
    }
}
