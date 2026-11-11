# -*- coding: utf-8 -*-
"""Быстрый предпросмотр одного мотива или фона: python tools/art/preview.py <имя> [ширина] [выходной.png].

Нужен только при разработке графики; готовые картинки собирает build_assets.py."""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import icons  # noqa: E402
import scenes  # noqa: E402


def main():
    name = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 440
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "_preview.png")
    t0 = time.time()
    if name.startswith("icon-"):
        im = icons.ICONS[name[5:]](width)
    elif name in scenes.SCENES:
        im = scenes.SCENES[name](width)
    else:
        im = getattr(icons, name)(width)
    im.save(out)
    print(f"{name}: {im.size} за {time.time() - t0:.1f} с -> {out}")


if __name__ == "__main__":
    main()
