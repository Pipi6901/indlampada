# -*- coding: utf-8 -*-
"""Собирает юридические страницы Deepam: политика конфиденциальности, условия использования, поддержка.

Источники — фрагменты `tools/legal/en/{privacy,terms,support}.html` (язык один — английский),
результат — `docs/legal/deepam/deepam-{privacy,terms,support}.html`: самодостаточные UTF-8 файлы без
внешних ресурсов. Их кладут на сайт (Google Sites через «Встроить» или любой хостинг): адрес политики
нужен App Store Connect и экрану оплаты (`Legal.privacy` в `DeepamCore/Legal.swift`).

Запуск:
    python tools/legal/build_legal.py                       # почта поддержки по умолчанию
    python tools/legal/build_legal.py --email help@example  # другая почта
    python tools/legal/build_legal.py --final               # и проверить, что заглушек не осталось
    python tools/legal/build_legal.py --embed               # вариант для встраивания в Google Sites
"""
import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "docs", "legal", "deepam")

# Почта поддержки подставлена из шаблонов команды; перед публикацией замените на свою (--email).
DEFAULT_EMAIL = "help@pmoffice.space"

PAGES = {
    "privacy": ("Deepam — Privacy Policy", "How the Deepam app handles your data."),
    "terms": ("Deepam — Terms of Use", "Terms of use of the Deepam app."),
    "support": ("Deepam — Support", "Help and answers for the Deepam app."),
}

CSS = """
  body{font:16px/1.6 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:720px;margin:40px auto;padding:0 20px;color:#241a2e}
  h1{font-size:28px}h2{font-size:20px;margin-top:32px}h3{font-size:17px;margin-top:24px}a{color:#b5541a}
  @media(prefers-color-scheme:dark){body{background:#1a1424;color:#ece4ee}a{color:#f4a340}}
"""


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read().strip()


def build(page, email, links=None, embed=False):
    title, desc = PAGES[page]
    links = links or {}
    body = read(os.path.join(HERE, "en", page + ".html")).replace("{{EMAIL}}", email)
    for target in PAGES:
        if target in links:
            body = body.replace(f'href="deepam-{target}.html"', f'href="{links[target]}"')
    # Во встроенном виде (Google Sites) ссылки открываются в новой вкладке: внутри окна
    # встраивания Google и почтовые ссылки не откроются.
    base = '<base target="_blank">' + chr(10) if embed else ""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{desc}">
{base}<style>{CSS}</style>
</head>
<body>
{body}
</body>
</html>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--email", default=DEFAULT_EMAIL)
    ap.add_argument("--final", action="store_true", help="упасть, если остались заглушки")
    ap.add_argument("--out-dir", default=OUT, help="куда писать страницы")
    ap.add_argument("--embed", action="store_true", help="вариант для встраивания в Google Sites")
    for page in PAGES:
        ap.add_argument(f"--link-{page}", help=f"адрес страницы «{page}» для ссылок между страницами")
    args = ap.parse_args()

    # следы прежних приложений (Библия, Коран) и британское написание
    stale = re.compile("Lampada|Misbah|Psalm|Bible|Quran|Qur.an|ayah|ayat|surah|Arabic|Colour|Centre", re.I)
    problems = []
    links = {page: getattr(args, f"link_{page}") for page in PAGES if getattr(args, f"link_{page}")}
    os.makedirs(args.out_dir, exist_ok=True)
    for page in PAGES:
        html = build(page, args.email, links, args.embed)
        for m in stale.finditer(html):
            problems.append(f"{page}: след прежнего приложения или британское написание: {m.group(0)}")
        if args.final and "{{" in html:
            problems.append(f"{page}: остались заглушки {{{{...}}}}")
        path = os.path.join(args.out_dir, f"deepam-{page}.html")
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(html)
        print(f"  {os.path.relpath(path, ROOT)}  {len(html.encode('utf-8')) / 1024:5.1f} КБ")
    if problems:
        print("ПРОБЛЕМЫ:")
        for p in problems:
            print("  ", p)
        sys.exit(1)


if __name__ == "__main__":
    main()
