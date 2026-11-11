import Foundation

/// Экран «Что нового» — один раз после обновления.
///
/// Только тем, кто прошёл онбординг раньше: новым всё то же самое показал
/// сам онбординг, и в его конце версия отмечается как показанная. Номер
/// версии — свой, а не из бандла: экран затевается под конкретные новинки, и
/// следующий выпуск без новинок не должен показывать его снова.
public enum WhatsNew {
    public static let version = "1.0.2"

    public static func isDue(_ settings: AppSettings) -> Bool {
        settings.hasSeenOnboarding && settings.whatsNewSeen != version
    }
}
