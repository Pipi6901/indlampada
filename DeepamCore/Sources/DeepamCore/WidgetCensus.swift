import Foundation

/// Перепись виджетов: что стоит на экранах сейчас против прошлого раза.
///
/// Система не сообщает приложению, что виджет поставили или убрали. Узнать это
/// можно только одним способом: спросить список при открытии и сравнить с
/// запомненным. Отсюда ограничение, которое надо держать в голове при чтении
/// отчётов: событие приходит не в момент действия, а при следующем открытии.
/// Кто поставил виджет и больше приложение не открывал, попадёт в отчёт с
/// опозданием или не попадёт вовсе.
///
/// Первая перепись событий не даёт, только запоминает. Иначе каждый, кто
/// обновился с прежней версии, разом отчитался бы обо всех своих давно
/// стоящих виджетах как о новых.
public struct WidgetCensus {
    /// Виджет одного вида и размера. Экземпляры считаются поштучно: два малых
    /// на рабочем столе — это два.
    public struct Slot: Hashable, Sendable {
        public let kind: String
        public let family: String

        public init(kind: String, family: String) {
            self.kind = kind
            self.family = family
        }

        /// На какой поверхности стоит. Размеры `accessory…` живут только на
        /// экране блокировки, `system…` — на рабочем столе. Малый в StandBy
        /// тоже `system`, отличить его система не даёт.
        public var surface: Surface? {
            if family.contains("accessory") { return .lockScreen }
            if family.contains("system") { return .homeScreen }
            return nil
        }

        /// Ключ для хранения. Ни в виде, ни в размере виджета вертикальной
        /// черты не бывает, так что разделитель однозначен.
        fileprivate var key: String { "\(kind)|\(family)" }

        fileprivate init?(key: String) {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            self.init(kind: parts[0], family: parts[1])
        }
    }

    private static let storageKey = "events.widgetCensus"
    private let store: UserDefaults

    /// Хранилище своё, а не общая группа: перепись ведёт только приложение,
    /// виджету она ни к чему.
    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    /// Сверяет с прошлым разом, запоминает текущее и возвращает разницу
    /// событиями — сначала снятые, потом поставленные.
    public func update(_ current: [Slot]) -> [AppEvent] {
        var now: [String: Int] = [:]
        for slot in current { now[slot.key, default: 0] += 1 }

        let saved = store.dictionary(forKey: Self.storageKey) as? [String: Int]
        store.set(now, forKey: Self.storageKey)
        guard let saved else { return [] }

        var removed: [AppEvent] = []
        var added: [AppEvent] = []
        for key in Set(now.keys).union(saved.keys).sorted() {
            guard let slot = Slot(key: key) else { continue }
            let delta = now[key, default: 0] - saved[key, default: 0]
            if delta < 0 {
                removed += Array(repeating: AppEvent.widgetRemoved(kind: slot.kind, family: slot.family),
                                 count: -delta)
            } else if delta > 0 {
                added += Array(repeating: AppEvent.widgetAdded(kind: slot.kind, family: slot.family),
                               count: delta)
            }
        }
        return removed + added
    }
}
