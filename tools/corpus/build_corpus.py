# -*- coding: utf-8 -*-
"""Сборка корпуса Deepam: санскритский оригинал (деванагари) + перевод по стихам Бхагавад-гиты.

На выходе (в ресурсы пакета DeepamCore):
    corpus-en.json  — карточки с переводом Анни Безант (1922) + санскрит

ТЕКСТЫ НЕ ПРАВЯТСЯ, кроме трёх оговорённых случаев. Каждая карточка — стихи из `corpus-src/gita.*`,
склеенные через пробел (перевод) или перенос строки (санскрит). Правки:
  1. запятая, точка с запятой или тире в самом конце карточки перевода меняются на точку (`finish`);
  2. следы оцифровки в переводе: пробел перед знаком препинания, хвостовой номер «(23», одинокая
     кавычка (`tidy`) — ни одного слова это не меняет;
  3. описки оцифровки санскрита из списка `CORRECTIONS`: найдены сверкой с независимой записью и
     проверены по общепринятому тексту; каждая обязана находиться в тексте, иначе сборка падает.
Сборка проверяет остальное обратной сверкой: текст карточки совпадает с исходником посимвольно.

Исходники (`corpus-src/`, скачаны `tools/corpus/fetch_gita.py`):
    gita.sa.txt          санскрит, деванагари: глава|стих|две строки через литерал \\n
    gita.en.besant.txt   перевод Анни Безант (4-е издание, 1922), общественное достояние
    gita.speakers.json   кто говорит: Krishna, Arjuna, Sanjaya, Dhritarashtra
    gita.crosscheck.json санскрит из gita/gita (Unlicense) — только для сверки

Запуск:  python tools/corpus/build_corpus.py [--report]
"""

import io
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "corpus-src")
OUT = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamCore", "Resources")

sys.path.insert(0, HERE)
import selection  # noqa: E402
import notes  # noqa: E402

COUNTS = [47, 72, 43, 42, 29, 47, 30, 28, 34, 42, 55, 20, 35, 27, 20, 24, 28, 78]  # 701 стих

EDITIONS = {
    "en": dict(id="en.besant", name="Besant", full="Annie Besant, 1922",
               license="Public Domain", source="en.wikisource.org"),
}
LANGS = list(EDITIONS)

SOURCE_CREDIT = "Sanskrit text and English translation: Annie Besant, The Bhagavad-Gita (1922), public domain"
# Уведомление об источнике: тот же текст стоит в DeepamCore/Legal.swift (тест сверяет их слово в слово).
SOURCE_NOTICE = (
    "Sanskrit text and English translation: The Bhagavad-Gita, translated by Annie Besant "
    "(4th ed., Theosophical Publishing House, 1922). Public domain. "
    "Digitized and proofread by Wikisource contributors."
)

# Описки оцифровки Викитеки (Безант, 4-е изд.): (глава, стих, было, стало).
CORRECTIONS = [
    (2, 41, "व्ययसायात्मिका", "व्यवसायात्मिका"),
    (2, 26, "नैनं शोचितुमर्हसि", "नैवं शोचितुमर्हसि"),
    (6, 39, "एतं मे संशयं", "एतन्मे संशयं"),
    (3, 43, "परं बुध्वा", "परं बुद्ध्वा"),
    (12, 18, "मानपमानयोः", "मानापमानयोः"),
    (15, 8, "गृहित्वैतानि", "गृहीत्वैतानि"),
    (2, 64, "वियुक्तैस्तुं विषयानि", "वियुक्तैस्तु विषयानि"),
    (18, 73, "स्मूतिर्लब्धा", "स्मृतिर्लब्धा"),
    (2, 3, "क्लैव्यं", "क्लैब्यं"),
    (2, 3, "त्यक्त्वोत्तिष्ट", "त्यक्त्वोत्तिष्ठ"),
]


def apply_corrections(sa):
    for ch, v, old, new in CORRECTIONS:
        assert old in sa[(ch, v)], f"правка {ch}.{v}: в тексте нет «{old}»"
        sa[(ch, v)] = sa[(ch, v)].replace(old, new)


def load_lines(name):
    out = {}
    for line in io.open(os.path.join(SRC, name), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        ch, v, t = line.split("|", 2)
        out[(int(ch), int(v))] = t.strip()
    return out


def label(ch, a, b):
    num = f"{a}" if a == b else f"{a}–{b}"
    return f"Bhagavad Gita {ch}.{num}"


def clean(text):
    """Только пробелы: ни слова, ни знака не трогаем."""
    return re.sub(r"[ \t]+", " ", text).strip()


def tidy(text):
    """Следы оцифровки, не слова: пробел перед знаком (остался от выброшенной сноски: «the Self , O Arjuna»),
    оборванный хвостовой номер стиха «(23», непарная кавычка у стиха, цитата которого продолжается в соседнем."""
    t = re.sub(r"\s+([,;:.!?])", r"\1", text)
    t = re.sub(r"\s*\(\s*\d+\s*$", "", t)
    if t.count('"') % 2 == 1:
        if t.startswith('"'):
            t = t[1:].lstrip()
        elif t.endswith('"'):
            t = t[:-1].rstrip()
    return t


TAIL = re.compile(r"[\s,;:—–-]+$")
STOPPED = re.compile(r"[.!?…][\"»”’)\]]*$")


def finish(text):
    """Знак в конце. Перевод кончает стих запятой, точкой с запятой или тире, если мысль продолжается
    в следующем. Карточка с таким концом выглядит оборванной, и такой знак меняется на точку (в
    исходнике он не трогается). Санскрит не меняется никогда."""
    if not TAIL.search(text):
        return text
    t = TAIL.sub("", text).rstrip()
    return t if STOPPED.search(t) else t + "."


def sanskrit(sa, ch, a, b):
    """Санскрит диапазона: стихи подряд, каждый в своих двух строках."""
    return "\n".join(sa[(ch, v)].replace("\\n", "\n") for v in range(a, b + 1))


def build():
    sa = load_lines("gita.sa.txt")
    apply_corrections(sa)
    en = load_lines("gita.en.besant.txt")
    speakers = json.load(io.open(os.path.join(SRC, "gita.speakers.json"), encoding="utf-8"))
    want = {(c, v) for c in range(1, 19) for v in range(1, COUNTS[c - 1] + 1)}
    assert set(sa) == want, "санскрит: набор стихов расходится с 701"
    assert set(en) == want, "перевод: набор стихов расходится с 701"

    cards = {lang: [] for lang in LANGS}
    used = {}
    for theme, ch, a, b in selection.passages():
        speaker = speakers[f"{ch}.{a}"]
        key = notes.passage_key(ch, a, b, speaker)
        used[key] = (ch, a, b, speaker)
        text = finish(tidy(clean(" ".join(en[(ch, v)] for v in range(a, b + 1)))))
        cid = f"{ch}-{a}" + ("" if a == b else f"-{b}")
        cards["en"].append({"id": cid, "p": key, "th": theme, "r": label(ch, a, b), "t": text,
                            "a": sanskrit(sa, ch, a, b)})

    bundles = {}
    for lang, ed in EDITIONS.items():
        contexts = {k: notes.context(k, v) for k, v in used.items()}
        bundles[lang] = {
            "schema": 2,
            "lang": lang,
            "edition": {"id": ed["id"], "name": ed["name"], "license": ed["license"], "source": ed["source"]},
            "sourceCredit": SOURCE_CREDIT,
            "sourceNotice": SOURCE_NOTICE,
            "counts": {"cards": len(cards[lang]), "passages": len(contexts)},
            "cards": cards[lang],
            "contexts": contexts,
        }
    return bundles, (sa, en)


def verify(bundles, sources):
    """Обратная сверка: карточка == исходник; перевод не пустой и не оборван; санскрит в деванагари."""
    sa, en = sources
    problems = []
    for lang, b in bundles.items():
        ids = [c["id"] for c in b["cards"]]
        if len(ids) != len(set(ids)):
            problems.append(f"{lang}: повторяются идентификаторы карточек")
        for c in b["cards"]:
            ch, a, *rest = (int(x) for x in c["id"].split("-"))
            e = rest[0] if rest else a
            expected = finish(tidy(clean(" ".join(en[(ch, v)] for v in range(a, e + 1)))))
            if c["t"] != expected:
                problems.append(f"{c['id']}: перевод не совпал с исходником")
            if sanskrit(sa, ch, a, e) != c["a"]:
                problems.append(f"{c['id']}: санскрит не совпал с исходником")
            if len(c["t"]) < 20:
                problems.append(f"{c['id']}: слишком короткий перевод")
            if c["t"][-1] in ",;:—–-":
                problems.append(f"{c['id']}: оборван на «{c['t'][-1]}»")
            if "|" in c["t"] or "<" in c["t"] or "[" in c["t"]:
                problems.append(f"{c['id']}: служебные символы в переводе")
            if not re.search("[ऀ-ॿ]", c["a"]) or re.search("[A-Za-z]", c["a"]):
                problems.append(f"{c['id']}: в санскрите не только деванагари")
            if "॥" not in c["a"]:
                problems.append(f"{c['id']}: у санскрита нет конца стиха «॥»")
            if c["p"] not in b["contexts"]:
                problems.append(f"{c['id']}: нет контекста {c['p']}")
        themes = {c["th"] for c in b["cards"]}
        if themes != set(selection.THEMES):
            problems.append(f"{lang}: набор состояний {themes ^ set(selection.THEMES)}")
    return problems


# ── сверка санскрита с независимой оцифровкой ───────────────────────────────

LABELS = ("श्री भगवानुवाच", "श्रीभगवानुवाच", "अर्जुन उवाच", "सञ्जय उवाच", "संजय उवाच", "धृतराष्ट्र उवाच")


def sa_norm(s):
    """Приводит запись к виду, в котором законные расхождения орфографии (анусвара вместо сочетания
    «носовой + согласный своей группы», конечное «म्» и «ं», знаки препинания, номера, известная
    поломка порядка знаков в gita/gita вроде «भक्ितमान्») исчезают."""
    s = unicodedata.normalize("NFC", s)
    s = re.sub("([क-ह]्)ि([क-ह])", r"\1\2ि", s)                       # «भक्ितमान्» -> «भक्तिमान्»
    s = re.sub(r"म्(?=[\s।॥]|$)", "ं", s)                             # «स्वम्» и «स्वं»
    s = re.sub(r"[0-9०-९\s​‌‍।॥|.,\-’'ऽ॰:]+", "", s)
    s = s.replace("़", "")                                       # нукта: «पितृ़न्» и «पितॄन्»
    s = s.replace("ॄ", "ृ")
    s = re.sub("(?:ङ्(?=[कखगघङ])|ञ्(?=[चछजझञ])|ण्(?=[टठडढण])|न्(?=[तथदधन])|म्(?=[पफबभम]))", "ं", s)
    s = s.replace("ः", "")
    return s


def strip_label(text):
    t = text.strip()
    for lab in LABELS:
        if t.startswith(lab):
            return t[len(lab):]
    return t


def crosscheck(bundles):
    """Сравнивает санскрит выбранных карточек с gita/gita; возвращает список расхождений."""
    cross = json.load(io.open(os.path.join(SRC, "gita.crosscheck.json"), encoding="utf-8"))
    sa = load_lines("gita.sa.txt")
    apply_corrections(sa)
    bad = []
    for c in bundles["en"]["cards"]:
        ch, a, *rest = (int(x) for x in c["id"].split("-"))
        e = rest[0] if rest else a
        for v in range(a, e + 1):
            mine = sa_norm(sa[(ch, v)].replace("\\n", ""))
            other = sa_norm(strip_label(cross[f"{ch}.{v}"]))
            if mine != other:
                i = next((k for k, (x, y) in enumerate(zip(mine, other)) if x != y), min(len(mine), len(other)))
                bad.append((f"{ch}.{v}", mine[max(0, i - 12):i + 14], other[max(0, i - 12):i + 14]))
    return bad


def main():
    bundles, sources = build()
    problems = verify(bundles, sources)
    if problems:
        print("ПРОБЛЕМЫ:", len(problems))
        for p in problems[:40]:
            print("  ", p)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for lang, b in bundles.items():
        path = os.path.join(OUT, f"corpus-{lang}.json")
        blob = json.dumps(b, ensure_ascii=False, separators=(",", ":"))
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(blob)
        size = os.path.getsize(path)
        total += size
        print(f"  corpus-{lang}.json  {b['counts']['cards']} карточек  {size / 1024:6.0f} КБ")
    print(f"всего {total / 1024:.0f} КБ; записано в {os.path.relpath(OUT, ROOT)}")
    bad = crosscheck(bundles)
    print(f"сверка санскрита с gita/gita: расхождений {len(bad)} из {len(bundles['en']['cards'])} карточек")
    if "--report" in sys.argv:
        for ref, mine, other in bad:
            print(f"  {ref}: у нас …{mine}…  у gita/gita …{other}…")


if __name__ == "__main__":
    main()
