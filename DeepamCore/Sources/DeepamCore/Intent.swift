import Foundation

/// Ответ на вопрос «Что тебе сейчас нужнее?» — второй экран онбординга.
///
/// Один ответ, а не мультивыбор, и он меняет путь: от него зависят экран
/// ветки сразу после вопроса и пейволл в конце — заголовок, подписи и порядок
/// плиток. На выдачу стихов сам ответ не влияет; влияет то, что человек
/// выберет на экране ветки (темы, время стиха, вид).
///
/// До 1.0.2 здесь был мультивыбор из пяти «намерений». Шесть шагов подряд
/// с вопросами теряли людей, и вопрос сжали до одного, который ведёт дальше.
public enum OnboardingGoal: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    /// «Утешение, когда тяжело» — дальше темы.
    case comfort
    /// «Помнить о вере каждый день» — дальше время стиха дня.
    case daily
    /// «Меньше листать ленту» — дальше «сколько уходит на ленту».
    case feed
    /// «Красиво на телефоне» — дальше вид стиха.
    case beauty

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .comfort: .goalComfort
        case .daily: .goalDaily
        case .feed: .goalFeed
        case .beauty: .goalBeauty
        }
    }

    public var subKey: L10n.Key {
        switch self {
        case .comfort: .goalComfortSub
        case .daily: .goalDailySub
        case .feed: .goalFeedSub
        case .beauty: .goalBeautySub
        }
    }

    /// Иконка ответа в ресурсах `DeepamUI`.
    public var asset: String { "goal-\(rawValue)" }

    /// Порядок плиток на пейволле этой ветки. Первые две подсвечены — это
    /// то, ради чего человек сюда шёл; остальные тише, но тоже на виду.
    public var unlocks: [PaywallUnlock] {
        switch self {
        case .comfort: [.standBy, .pictures, .wallpaper, .sets, .fonts, .icons]
        case .daily: [.standBy, .wallpaper, .sets, .pictures, .fonts, .icons]
        case .feed: [.standBy, .wallpaper, .pictures, .sets, .fonts, .icons]
        case .beauty: [.icons, .pictures, .sets, .fonts, .standBy, .wallpaper]
        }
    }
}

/// Ответ ветки «Меньше ленты»: сколько в день уходит на ленту.
///
/// Ответ никуда не сохраняется — по нему только считается, сколько дней в
/// году это составляет, и уходит событие в аналитику. Часы у каждого
/// варианта — середина диапазона, у крайних — правдоподобная точка.
public enum FeedHours: String, Sendable, Hashable, CaseIterable, Identifiable {
    case underOne = "lt1"
    case oneToTwo = "1-2"
    case twoToFour = "2-4"
    case overFour = "4+"

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .underOne: .feedUnderOne
        case .oneToTwo: .feedOneToTwo
        case .twoToFour: .feedTwoToFour
        case .overFour: .feedOverFour
        }
    }

    public var hoursPerDay: Double {
        switch self {
        case .underOne: 0.5
        case .oneToTwo: 1.5
        case .twoToFour: 3
        case .overFour: 5
        }
    }

    /// Целых суток в году. Вниз, а не по правилам округления: «≈ 45 дней» не
    /// должно оказаться больше, чем выходит на самом деле.
    public var daysPerYear: Int { Int(hoursPerDay * 365 / 24) }
}

/// Плитка в сетке платного набора на пейволле.
///
/// Здесь ровно то, что подписка действительно открывает, — и ничего сверх.
/// Раньше в списке стояли «Все темы» и «Палитры»: тем `EntitlementStore` не
/// проверяет вовсе, они бесплатны для всех, а «палитры» не назывались так
/// нигде, кроме этой плитки. Продавать бесплатное — верный способ получить
/// возврат денег и отзыв о том, что за подписку ничего не изменилось.
///
/// Каждый случай сверен с `EntitlementStore.isUnlocked`: закрыты поверхности
/// (StandBy и обои), наборы цвета, картинки, шрифты и иконки приложения.
public enum PaywallUnlock: String, Sendable, Hashable, CaseIterable, Identifiable {
    case standBy
    case wallpaper
    case sets
    case pictures
    case fonts
    case icons

    public var id: String { rawValue }

    public var titleKey: L10n.Key {
        switch self {
        case .standBy: .unlockStandBy
        case .wallpaper: .unlockWallpaper
        case .sets: .unlockSets
        case .pictures: .unlockPictures
        case .fonts: .unlockFonts
        case .icons: .unlockIcons
        }
    }

    /// Символ из SF Symbols. В макете стоят иконки lucide, но тащить целый
    /// набор ради шести значков не стоит — у системного набора есть близкие.
    public var symbol: String {
        switch self {
        case .standBy: "moon.zzz"
        case .wallpaper: "photo.on.rectangle"
        case .sets: "paintpalette"
        case .pictures: "photo"
        case .fonts: "textformat"
        case .icons: "app.badge"
        }
    }

}
