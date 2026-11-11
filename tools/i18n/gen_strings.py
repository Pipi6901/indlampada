# -*- coding: utf-8 -*-
"""Собирает DeepamCore/Sources/DeepamCore/Strings.swift.

Язык один — английский. Основа — `en_base.json` (все ключи интерфейса, термины уже «verse» и «Gita»);
здесь же лежат ручные правки под индуистский продукт (OVERRIDE), названия состояний и
названия фонов и иконок. Образцы стихов в онбординге (`demoVerse`, `pauseVerse`) берутся из
готового корпуса, а не набираются руками.

Как добавить язык: колонка в `LANGS`, перевод каждой строки в своём файле (как `en_base.json`),
ветка в `AppLocale` и в `L10n.count` (формы множественного числа).

Запуск: python tools/i18n/gen_strings.py
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

LANGS = ("en",)

# Ключи, которых больше нет в интерфейсе (фоны, иконки и набор цвета прежнего приложения).
REMOVED = {
    "sceneDesert", "sceneStars", "sceneDome", "sceneLantern", "sceneGarden", "sceneMosaic", "sceneLattice",
    "iconMosaic", "iconStar", "iconDome", "iconRosette", "styleEmerald",
}
# Новые ключи (порядок — как в перечислении).
ADDED = [
    "sceneHimalaya", "sceneGanga", "sceneTemple", "sceneDiya", "sceneLotus", "sceneRangoli", "sceneMandala",
    "iconLotus", "iconOm", "iconTemple", "iconMandala", "styleSaffron",
]

OVERRIDE = {
    "heroEditions": "Sanskrit original · Besant translation",
    "languageTitle": "Text and translation",
    "languageSubtitle": "Sanskrit original with an English translation",
    "languageAndEdition": "Text and translation",
    "goalDaily": "Keep the Gita close every day",
    "contextPill": "Who speaks, and to whom",
    "pwSub": ("Deepam has no ads. It runs on the people who use it — a subscription helps it keep "
              "shining"),
    "showOriginal": "Show the Sanskrit text",
    "stepPause3": "Add the “Verse pause” action",
    # фоны
    "sceneHimalaya": "Himalaya",
    "sceneGanga": "Ganga",
    "sceneTemple": "Temple",
    "sceneDiya": "Diya",
    "sceneLotus": "Lotus",
    "sceneRangoli": "Rangoli",
    "sceneMandala": "Mandala",
    # иконки
    "iconLotus": "Lotus",
    "iconOm": "Om",
    "iconTemple": "Temple",
    "iconMandala": "Mandala",
    # набор цвета
    "styleSaffron": "Saffron",
}

# Показываемые названия состояний. Идентификаторы (ключи) — те же, что в корпусе: по ним
# фильтруется пул, и они русские только по истории; показывать их нельзя.
THEMES = {
    "тревога": "Anxiety",
    "страх": "Fear",
    "утрата": "Loss",
    "благодарность": "Gratitude",
    "прощение": "Forgiveness",
    "вина": "Regret",
    "доверие": "Surrender",
    "надежда": "Hope",
    "бессонница": "Sleeplessness",
    "усталость": "Tiredness",
    "начало дела": "A new start",
    "решение": "A decision",
    "сомнение": "Doubt",
    "одиночество": "Loneliness",
    "немощь": "Weakness",
    "любовь": "Devotion",
}

# Какие карточки корпуса идут образцами: (ключ строки, id карточки)
DEMO = {"demo": "6-19", "pause": "6-26"}


def corpus_cards():
    path = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamCore", "Resources", "corpus-en.json")
    data = json.load(io.open(path, encoding="utf-8"))
    return {c["id"]: c for c in data["cards"]}, data


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    base = json.load(io.open(os.path.join(HERE, "en_base.json"), encoding="utf-8"))
    cards, bundle = corpus_cards()

    keys = [k for k in base if k not in REMOVED] + [k for k in ADDED if k not in base]
    rows = {}
    for key in keys:
        rows[key] = [OVERRIDE.get(key, base.get(key))]
    for name, cid in DEMO.items():
        card = cards[cid]
        rows[f"{name}Verse"] = [card["t"]]
        rows[f"{name}Reference"] = [card["r"]]

    missing = [k for k, r in rows.items() if not r[0]]
    if missing:
        sys.exit(f"нет строки для: {missing}")
    # у каждой добавленной строки должен быть текст
    for k in ADDED:
        if k not in OVERRIDE:
            sys.exit(f"нет текста для нового ключа {k}")

    # состояния должны совпадать с корпусом
    corpus_themes = {c["th"] for c in cards.values()}
    if corpus_themes != set(THEMES):
        sys.exit(f"состояния: корпус и таблица расходятся: {corpus_themes ^ set(THEMES)}")

    # следы прежнего продукта в строках
    bad = re.compile(r"Quran|Qur'an|Allah|ayah|ayat|surah|Arabic|Lampada|Bible|Scripture|Christ|Jesus|Misbah|"
                     r"Koran|Islam|Muslim|mosque|prayer rug|\bWord\b", re.I)
    for k, r in rows.items():
        if bad.search(r[0]):
            print("СЛЕД:", k, "—", r[0])

    ph = re.compile(r"%(\d\$)?[@d]")
    for k, r in rows.items():
        if k.endswith("Verse"):
            continue
        # подстановки — только известные; «%» без буквы в тексте быть не должно
        for m in re.finditer(r"%(?!\d?\$?[@d])", r[0]):
            print("ПОДСТАНОВКА?:", k, r[0])

    enum_lines, line = [], []
    for k in rows:
        line.append(k)
        if len(line) == 6:
            enum_lines.append("        case " + ", ".join(line))
            line = []
    if line:
        enum_lines.append("        case " + ", ".join(line))

    table_lines = [f"        .{k}: [{', '.join(q(v) for v in r)}]," for k, r in rows.items()]
    theme_lines = [f"        {q(t)}: [{q(n)}]," for t, n in sorted(THEMES.items())]

    swift = f'''import Foundation

/// Строки интерфейса. Сейчас язык один — английский.
///
/// Таблица в коде, а не `.strings`-файлы, по одной причине: язык интерфейса
/// здесь выбирает человек в настройках приложения, а не система. Стандартный
/// механизм локализации подставляет язык устройства и заставляет держать
/// отдельный `Bundle` на каждый `lproj`; здесь же достаточно словаря, который
/// к тому же виден на ревью целиком и не может «потерять ключ» в рантайме.
///
/// Порядок значений в каждой строке один: по языкам из `AppLocale` (сейчас en).
///
/// ФАЙЛ СГЕНЕРИРОВАН `tools/i18n/gen_strings.py` — не править руками: правки
/// пропадут при следующей сборке. Образцы стихов (`demoVerse`, `pauseVerse`) берутся
/// из корпуса, а не набираются.
public struct L10n: Sendable, Hashable {{
    public let locale: AppLocale

    public init(_ locale: AppLocale) {{
        self.locale = locale
    }}

    public subscript(_ key: Key) -> String {{
        let row = L10n.table[key] ?? [""]
        let value = row[min(index, row.count - 1)]
        guard value.isEmpty else {{ return value }}
        // Пустая строка означает недостающий перевод: показываем первую колонку,
        // а не пустоту. Заметить это на глаз проще, чем дыру в интерфейсе.
        return row[0]
    }}

    /// Подстановка чисел: «Сейчас 3 из 7».
    public func callAsFunction(_ key: Key, _ arguments: CVarArg...) -> String {{
        String(format: self[key], arguments: arguments)
    }}

    /// Число со словом в нужной форме: «1 day», «45 days».
    ///
    /// Формы лежат в строке таблицы через вертикальную черту: у английского две
    /// (единственное и множественное).
    public func count(_ number: Int, _ key: Key) -> String {{
        let forms = self[key].split(separator: "|").map(String.init)
        let index: Int
        switch locale {{
        case .en:
            index = number == 1 ? 0 : 1
        }}
        return "\\(number) \\(forms[min(index, forms.count - 1)])"
    }}

    public enum Key: String, Sendable, Hashable, CaseIterable {{
{chr(10).join(enum_lines)}
    }}

    // Порядок в строке: en
    private static let table: [Key: [String]] = [
{chr(10).join(table_lines)}
    ]
}}

extension L10n {{
    /// Название состояния для чипов в онбординге.
    ///
    /// Состояния лежат в корпусе одинаковыми во всех языках — по ним
    /// фильтруется пул, и общий идентификатор здесь правильный. Но показывать
    /// его нельзя: идентификаторы русские. Отдельная таблица, а не ключи в общем
    /// перечислении, потому что список задаёт корпус, а не код; тест сверяет
    /// одно с другим.
    public func theme(_ id: String) -> String {{
        guard let row = L10n.themes[id] else {{ return id }}
        return row[min(index, row.count - 1)]
    }}

    /// Порядок значений тот же: en.
    static let themes: [String: [String]] = [
{chr(10).join(theme_lines)}
    ]

    /// Номер языка в строке таблицы.
    var index: Int {{
        switch locale {{
        case .en: 0
        }}
    }}

    /// Название поверхности. Отдельный метод, потому что у StandBy и Apple Watch
    /// переводить нечего — это имена продуктов Apple.
    public func name(_ surface: Surface) -> String {{
        surface.titleKey.map {{ self[$0] }} ?? surface.untranslatedTitle
    }}

    /// Дата для макета экрана блокировки.
    ///
    /// Число условное — как и 9:41 на всех снимках Apple, — но написано оно
    /// должно быть на языке интерфейса.
    public var mockDate: String {{
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: 2025, month: 9, day: 3))
        else {{ return "" }}
        return date.formatted(
            .dateTime.weekday(.wide).day().month(.wide)
                .locale(locale.formattingLocale)
        )
    }}
}}
'''
    out = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamCore", "Strings.swift")
    with io.open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(swift)
    print(f"записано {os.path.relpath(out, ROOT)}: {len(rows)} ключей, {len(THEMES)} состояний")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
