# -*- coding: utf-8 -*-
"""Скачивает «The Bhagavad-Gita» в переводе Анни Безант (4-е изд., 1922) с английской Викитеки и
раскладывает по стихам: санскрит в деванагари и английский перевод.

Результат (в `corpus-src/`):
    gita.sa.txt          глава|стих|санскрит (две строки через литерал \\n, без имени говорящего и номера)
    gita.en.besant.txt   глава|стих|английский перевод (без сносок)
    gita.speakers.json   {"2.47": "Krishna", ...} — кто говорит (по пометкам «उवाच» у gita/gita)
    gita.crosscheck.json {"2.47": "санскрит из gita/gita", ...} — только для сверки, в приложение не идёт

Источники и лицензии — `docs/TRANSLATIONS.md`. Запуск: python tools/corpus/fetch_gita.py
"""
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

from bs4 import BeautifulSoup

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "corpus-src")
UA = {"User-Agent": "deepam-corpus-builder/1.0"}
DEV = str.maketrans("०१२३४५६७८९", "0123456789")
HAS_DEV = re.compile("[ऀ-ॿ]")
CHAPTERS = 18
COUNTS = [47, 72, 43, 42, 29, 47, 30, 28, 34, 42, 55, 20, 35, 27, 20, 24, 28, 78]  # 701 стих

def speaker_of(label):
    """Имя говорящего по строке-метке: «श्रीभगवानुवाच», «अर्जुन उवाच», «सञ्जय उवाच», «धृतराष्ट्र उवाच»."""
    label = label.replace(" ", "")
    if "श्रीभगवान" in label:
        return "Krishna"
    if "अर्जुन" in label:
        return "Arjuna"
    if "सञ्जय" in label or "संजय" in label:
        return "Sanjaya"
    if "धृतराष्ट्र" in label:
        return "Dhritarashtra"
    return None


def http(url):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=120).read()


def fetch_discourse(n):
    q = urllib.parse.urlencode({"action": "parse", "page": f"Bhagavad-Gita (Besant 4th)/Discourse {n}",
                                "prop": "text", "disablelimitreport": 1, "format": "json"})
    return json.loads(http("https://en.wikisource.org/w/api.php?" + q))["parse"]["text"]["*"]


def clean(t):
    t = t.replace("​", "").replace("\xa0", " ")
    t = re.sub(r"\s*\[\s*\d+\s*\]\s*", " ", t)           # сноски [ 1 ]
    t = re.sub(r"[ \t]+", " ", t)
    return t.strip()


def parse_chapter(html, n):
    """Блок с деванагари — санскрит стиха (номер в конце «॥ N ॥»); всё латинское после него — английский
    перевод (абзац <p> или стихотворный блок)."""
    soup = BeautifulSoup(html, "lxml")
    for s in soup(["style", "script"]):
        s.decompose()
    for br in soup.find_all("br"):
        br.replace_with("\n")
    box = soup.find("div", class_="prp-pages-output")
    verses, cur = [], None

    def flush():
        nonlocal cur
        if cur:
            verses.append(cur)
        cur = None

    for el in box.children:
        name = getattr(el, "name", None)
        if not name:
            continue
        cls = el.get("class") or []
        raw = el.get_text("", strip=False)
        if name == "div" and "wst-block-center" in cls:
            t = re.sub(r"[ \t]*\n[ \t]*", "\n", raw.replace("​", "")).strip()
            if not t:
                continue
            if HAS_DEV.search(t):
                if cur and cur["en"]:
                    flush()
                if cur is None:
                    cur = dict(sa=[], en=[])
                cur["sa"].append(t)
            elif cur is not None:
                cur["en"].append(clean(re.sub(r"\s*\n\s*", " ", t)))
        elif name == "p" and cur is not None:
            t = clean(raw)
            if t:
                cur["en"].append(t)
    flush()
    out = []
    for v in verses:
        nums = []
        for b in v["sa"]:
            m = re.search(r"॥\s*([०-९]+)\s*॥\s*$", b.strip())
            if m:
                nums.append(int(m.group(1).translate(DEV)))
        if not nums:
            continue                                   # колофон главы
        sa_text = "\n".join(v["sa"])
        m = LABEL.search(sa_text)
        out.append(dict(ch=n, verse=nums[0], nums=nums, sa=sa_text, en=" ".join(v["en"]),
                        speaker=speaker_of(m.group(1)) if m else None))
    return out


# Метка говорящего в начале санскритского блока: «श्रीभगवानुवाच ।», «अर्जुन उवाच ।», «सञ्जय उवाच ।».
LABEL = re.compile(r"^\s*([^\n।॥]{0,24}?वाच)\s*।", re.M)
SPEAKER_PREFIX = re.compile(r"^\s*[^\n।॥]{0,24}?वाच\s*।\s*", re.M)


def clean_sanskrit(block):
    """Убирает «श्रीभगवानुवाच ।», номер «॥ N ॥», пустые строки; два полустишия — две строки."""
    t = block.replace("​", "")
    t = SPEAKER_PREFIX.sub("", t, count=1)
    t = re.sub(r"॥\s*[०-९]+\s*॥\s*$", "॥", t.strip())
    t = t.replace(":", "ः")                             # ASCII-двоеточие вместо висарги (описка оцифровки)
    lines = [re.sub(r"\s+", " ", ln).strip() for ln in t.split("\n") if ln.strip()]
    text = "\n".join(lines)
    if "\n" not in text:
        parts = re.split(r"\s।\s", text, maxsplit=1)
        if len(parts) == 2:
            text = parts[0] + " ।\n" + parts[1]
    return text


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(SRC, exist_ok=True)
    allv = []
    for n in range(1, CHAPTERS + 1):
        vs = parse_chapter(fetch_discourse(n), n)
        got = [v["verse"] for v in vs]
        assert got == list(range(1, COUNTS[n - 1] + 1)), f"глава {n}: нумерация {got[:5]}…, ждали 1–{COUNTS[n - 1]}"
        assert all(v["en"] for v in vs), f"глава {n}: у стиха нет перевода"
        allv += vs
        print(f"  глава {n}: {len(vs)} стихов")
        time.sleep(0.3)
    sa_lines = []
    for v in allv:
        sa_text = clean_sanskrit(v["sa"]).replace(chr(10), "\\n")      # перенос строки — литерал \n
        sa_lines.append(f"{v['ch']}|{v['verse']}|{sa_text}")
    en_lines = []
    for v in allv:
        en_text = re.sub(r"\s+", " ", v["en"]).strip()
        en_text = re.sub(r"\s*\(\s*\d+\s*\)\s*$", "", en_text)        # хвостовой номер «(47)»
        en_lines.append(f"{v['ch']}|{v['verse']}|{en_text}")
    with io.open(os.path.join(SRC, "gita.sa.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sa_lines) + "\n")
    with io.open(os.path.join(SRC, "gita.en.besant.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(en_lines) + "\n")

    # говорящий и сверочный санскрит из gita/gita (Unlicense). Берём только поле text.
    g = json.loads(http("https://raw.githubusercontent.com/gita/gita/main/data/verse.json"))
    cross = {f"{x['chapter_number']}.{x['verse_number']}": x["text"] for x in g}
    # говорящий: метка у стиха, где он меняется (в оцифровке Безант они стоят надёжно), дальше по цепочке
    speakers, cur = {}, None
    for v in allv:
        cur = v["speaker"] or cur
        speakers[f"{v['ch']}.{v['verse']}"] = cur
    with io.open(os.path.join(SRC, "gita.speakers.json"), "w", encoding="utf-8") as f:
        json.dump(speakers, f, ensure_ascii=False, indent=0)
    with io.open(os.path.join(SRC, "gita.crosscheck.json"), "w", encoding="utf-8") as f:
        json.dump(cross, f, ensure_ascii=False, indent=0)
    print("готово:", len(allv), "стихов")


if __name__ == "__main__":
    main()
