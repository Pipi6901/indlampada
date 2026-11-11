import Foundation

/// Тариф на платном экране.
///
/// Цена здесь — уже готовая строка, а не число: её форматирует магазин, в
/// каждой стране своя валюта и свои правила записи. Складывать «$» с числом
/// самим значило бы показать доллары там, где Apple возьмёт рубли.
public struct PaywallPlan: Sendable, Hashable, Identifiable {
    public enum Period: String, Sendable, Hashable {
        case week, month, year
    }

    public let period: Period
    public let price: String
    /// Длина вводного бесплатного периода в днях, 0 — его нет. Берётся из магазина:
    /// у каждого тарифа он свой (решение от 10.11.2026: 3 дня у недельного и
    /// месячного, 7 у годового), и менять его можно в App Store Connect без релиза.
    public let trialDays: Int

    public var hasTrial: Bool { trialDays > 0 }

    public init(period: Period, price: String, trialDays: Int = 0) {
        self.period = period
        self.price = price
        self.trialDays = max(0, trialDays)
    }

    public var id: String { period.rawValue }

    public var nameKey: L10n.Key {
        switch period {
        case .week: .planWeek
        case .month: .planMonth
        case .year: .planYear
        }
    }

    /// «в неделю», «в месяц», «в год» — период оплаты.
    public var noteKey: L10n.Key {
        switch period {
        case .week: .planWeekNote
        case .month: .planMonthNote
        case .year: .planYearNote
        }
    }

    /// Подпись под ценой на карточке: «3 дня бесплатно» у тарифа с триалом, иначе
    /// период оплаты.
    public func note(_ l10n: L10n) -> String {
        hasTrial ? l10n(.planTrialNote, l10n.count(trialDays, .daysUnit)) : l10n[noteKey]
    }

    /// Цена с периодом: «$1.99 в неделю». Для строки «Потом …» под кнопкой.
    public func priceWithPeriod(_ l10n: L10n) -> String {
        "\(price) \(l10n[noteKey])"
    }

    /// Надпись на кнопке покупки: с триалом зовём его начать, без него называем цену.
    public func callToAction(_ l10n: L10n) -> String {
        hasTrial ? l10n(.pwTrialCta, l10n.count(trialDays, .daysUnit)) : l10n(.pwSubscribeCta, price)
    }

    /// Заглушка на случай, когда магазин ещё не ответил или в сборке его нет
    /// вовсе. Цены и триалы совпадают с App Store Connect для США, и по ним экран
    /// можно смотреть без сети.
    public static let placeholder: [PaywallPlan] = [
        PaywallPlan(period: .week, price: "$1.99", trialDays: 3),
        PaywallPlan(period: .month, price: "$3.99", trialDays: 3),
        PaywallPlan(period: .year, price: "$14.99", trialDays: 7),
    ]

    /// Что предложить по умолчанию. Годовой: он выгоднее человеку и с самым
    /// длинным бесплатным периодом.
    public static let preferred: Period = .year
}
