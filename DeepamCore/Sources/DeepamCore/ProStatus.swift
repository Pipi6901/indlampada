import Foundation

/// Что было известно о подписке при последнем ответе RevenueCat.
///
/// Нужен там, куда RevenueCat не дотягивается, — в расширении виджета. Линковать
/// его туда нельзя: лимит памяти у виджета жёсткий. Поэтому приложение кладёт
/// этот снимок в общую группу, а виджет читает.
///
/// Снимок, а не флаг «подписан»: виджет рисует расписание на две недели вперёд,
/// и ему нужно знать не «есть ли подписка сейчас», а «будет ли она в момент
/// каждой записи».
public struct ProStatus: Codable, Equatable, Sendable {
    /// Действовало ли право на момент ответа.
    public var isActive: Bool

    /// Конец оплаченного или пробного периода. `nil` — без срока.
    public var expiresAt: Date?

    /// Продлится ли подписка сама. После отмены триала здесь `false`, хотя
    /// право ещё действует до конца пробной недели.
    public var willRenew: Bool

    /// Идёт ли бесплатный период. Вместе с `willRenew == false` это и есть
    /// отменённый триал — по нему показывается лист «почему?».
    public var isTrial: Bool

    public init(isActive: Bool, expiresAt: Date?, willRenew: Bool, isTrial: Bool = false) {
        self.isActive = isActive
        self.expiresAt = expiresAt
        self.willRenew = willRenew
        self.isTrial = isTrial
    }

    /// Снимок, записанный прежней версией, поля `isTrial` не знает. Без
    /// ручного разбора он не прочитался бы вовсе, и виджет до первого ответа
    /// RevenueCat считал бы подписку неизвестной.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        willRenew = try container.decode(Bool.self, forKey: .willRenew)
        isTrial = try container.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
    }

    /// Триал отменён, но ещё идёт: человек выключил продление.
    public var isCancelledTrial: Bool { isActive && isTrial && !willRenew }

    /// Подписки нет и не было.
    ///
    /// Не `none`: в выражении `x ?? .none` такое имя путается с
    /// `Optional.none`, и компилятор выбирает не то, что имелось в виду.
    public static let noSubscription = ProStatus(isActive: false, expiresAt: nil, willRenew: false)

    /// Действует ли Pro в момент `date`.
    ///
    /// Продлевающуюся подписку считаем действующей, даже когда дата из снимка
    /// уже прошла: значит, она тихо продлилась, пока приложение не открывали, и
    /// нового срока снимок просто не знает. Иначе подписчик, неделю не
    /// заходивший в приложение, увидел бы в StandBy замок за собственные деньги.
    /// Строги по дате только отменённые — им продлиться нечем.
    public func grants(at date: Date) -> Bool {
        guard isActive else { return false }
        guard !willRenew, let expiresAt else { return true }
        return date < expiresAt
    }
}
