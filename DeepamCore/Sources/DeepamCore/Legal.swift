import Foundation

/// Ссылки, которые обязаны быть рядом с подпиской.
///
/// Правило 3.1.2 требует их в двух местах сразу: на странице App Store и в
/// самом приложении, на экране, где человек платит. В описании они лежат
/// текстом — из-за их отсутствия ревью и отклонило первую подачу. Здесь та же
/// пара для пейволла.
///
/// Условия — стандартный EULA Apple, тот самый, на который человек и так
/// соглашается при покупке. Своё соглашение писать не нужно: пока его нет в
/// App Store Connect, действует это, и подсовывать вместо него самодельный
/// текст было бы неправдой.
public enum Legal {
    public static let terms = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Уведомление об источнике текста. Санскрит и перевод взяты из одной книги, срок защиты
    /// которой истёк (Безант умерла в 1933 году, издание 1922 года), так что лицензия ничего не
    /// требует; источник указан из уважения к оцифровщикам и чтобы текст можно было сверить.
    /// Те же слова едут в каждом бандле корпуса (`sourceNotice`) и стоят на экране выбора языка.
    public static let sourceNotice =
        "Sanskrit text and English translation: The Bhagavad-Gita, translated by Annie Besant "
        + "(4th ed., Theosophical Publishing House, 1922). Public domain. "
        + "Digitized and proofread by Wikisource contributors."

    public static let sourceURL = URL(string: "https://en.wikisource.org/wiki/Bhagavad-Gita_(Besant_4th)")!

    /// Политика конфиденциальности, условия и поддержка опубликованы на Google Sites
    /// (`sites.google.com/view/deepam-app`): тексты и сборщик — `tools/legal`, готовые
    /// страницы для встраивания — `docs/legal/google-sites`. Страница сама выбирает
    /// язык по устройству. Условия и поддержка — `/terms` и `/support`
    /// на том же сайте.
    public static let privacy = URL(
        string: "https://sites.google.com/view/deepam-app/privacy")!
}
