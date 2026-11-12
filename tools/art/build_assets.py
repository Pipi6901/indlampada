# -*- coding: utf-8 -*-
"""Собирает графику Deepam: фоны-картинки, иконки приложения, арт онбординга.

Всё рисуется кодом (`hart.py`, `motifs*.py`, `scenes.py`, `icons.py`): без нейросетей, без чужих картинок,
без людей, божеств и животных. Результат воспроизводится из исходников.

Пишет:
  DeepamCore/Sources/DeepamUI/Resources/Media.xcassets   фоны, плитки иконок, арт онбординга
  App/Deepam/Assets.xcassets                              иконки приложения (основная и альтернативные)
  DeepamCore/Sources/DeepamCore/VerseScene.swift         параметры фонов, посчитанные по картинкам
  блок `VerseScene.focus` в DeepamCore/Sources/DeepamUI/Background.swift

Запуск: python tools/art/build_assets.py
"""
import json
import os
import shutil
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import icons  # noqa: E402
import scenes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
MEDIA = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamUI", "Resources", "Media.xcassets")
APPICONS = os.path.join(ROOT, "App", "Deepam", "Assets.xcassets")

LIGHT_TEXT = 0xF4E8DC
DARK_TEXT = 0x2B1A14

# ключ, точка фокуса на высоком кадре, акцент (цвет ссылок и кнопок поверх картинки)
SCENES = [
    dict(key="himalaya", focus=(0.5, 0.80), accent=0xF2A14E),
    dict(key="ganga", focus=(0.5, 0.34), accent=0xF0913A),
    dict(key="temple", focus=(0.5, 0.74), accent=0xFFA64A),
    dict(key="diya", focus=(0.5, 0.22), accent=0xFFB347),
    dict(key="lotus", focus=(0.5, 0.80), accent=0xFF8A5C),
    dict(key="rangoli", focus=(0.5, 0.50), accent=0x9B1B2A),
    dict(key="mandala", focus=(0.5, 0.40), accent=0xF2C45E),
]
ICON_KEYS = ["default", "night", "lotus", "om", "dawn", "temple", "mandala", "light"]


# ── запись каталогов ────────────────────────────────────────────────────────

def write_imageset(name, filename, image, fmt="JPEG", quality=88):
    d = os.path.join(MEDIA, f"{name}.imageset")
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    path = os.path.join(d, filename)
    if fmt == "JPEG":
        image.convert("RGB").save(path, "JPEG", quality=quality, optimize=True, progressive=False)
    else:
        image.save(path, fmt, optimize=True)
    contents = {
        "images": [{"filename": filename, "idiom": "universal", "scale": "1x"},
                   {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    with open(os.path.join(d, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)


def write_appicon(name, image):
    d = os.path.join(APPICONS, f"{name}.appiconset")
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    image.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(os.path.join(d, f"{name}.png"), "PNG", optimize=True)
    contents = {"images": [{"filename": f"{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(d, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)


# ── измерение: чем подпирать текст ─────────────────────────────────────────

def _lin(a):
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def _lum(a):
    lin = _lin(a)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def _rgb(h):
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], float) / 255


def measure(tall):
    """По полосе, где лежит стих (27–67% высоты): светлый или тёмный текст и какая подложка доводит контраст до 4,5:1."""
    a = np.asarray(tall.convert("RGB")).astype(float) / 255
    h = a.shape[0]
    band = a[int(0.27 * h):int(0.67 * h)]
    lum = _lum(band)
    light_text = lum.mean() < 0.22
    text_lum = _lum(_rgb(LIGHT_TEXT if light_text else DARK_TEXT))
    scrim = 0.6
    for step in range(0, 61):
        alpha = step / 100
        tint = 0.0 if light_text else 1.0
        adj = band * (1 - alpha) + tint * alpha
        l2 = _lum(adj)
        if light_text:
            ok = (text_lum + 0.05) / (np.percentile(l2, 92) + 0.05) >= 4.5
        else:
            ok = (np.percentile(l2, 8) + 0.05) / (text_lum + 0.05) >= 4.5
        if ok:
            scrim = alpha
            break
    mean_band = tuple(int(x) for x in (band.reshape(-1, 3).mean(0) * 255))
    mean_all = tuple(int(x) for x in (a.reshape(-1, 3).mean(0) * 255))
    to_hex = lambda c: (c[0] << 16) | (c[1] << 8) | c[2]
    return dict(light_text=bool(light_text), scrim=round(scrim, 2), background=to_hex(mean_band), second=to_hex(mean_all))


def crops(tall, focus):
    """Квадрат и полоса для виджетов — вокруг той же точки фокуса, что и в приложении."""
    w, h = tall.size
    fy = focus[1]
    sq = int(min(max(fy * h - w / 2, 0), h - w))
    square = tall.crop((0, sq, w, sq + w)).resize((1092, 1092), Image.LANCZOS)
    wide_h = int(w * 510 / 1092)
    wy = int(min(max(fy * h - wide_h / 2, 0), h - wide_h))
    wide = tall.crop((0, wy, w, wy + wide_h)).resize((1092, 510), Image.LANCZOS)
    return square, wide


def build_scenes():
    params = {}
    for sc in SCENES:
        key = sc["key"]
        t = time.time()
        tall = scenes.SCENES[key](1320)
        assert tall.size == (1320, 2868), tall.size
        square, wide = crops(tall, sc["focus"])
        write_imageset(f"bg-{key}-tall", f"bg-{key}-tall.jpg", tall, quality=86)
        write_imageset(f"bg-{key}-square", f"bg-{key}-square.jpg", square, quality=86)
        write_imageset(f"bg-{key}-wide", f"bg-{key}-wide.jpg", wide, quality=86)
        m = measure(tall)
        m.update(focus=sc["focus"], accent=sc["accent"])
        params[key] = m
        print(f"  фон {key:9s} светлый текст={m['light_text']!s:5s} подложка={m['scrim']:.2f}  ({time.time() - t:.1f} с)")
    return params


# ── Swift: параметры фонов ──────────────────────────────────────────────────

def write_scene_swift(params):
    order = [s["key"] for s in SCENES]
    light = [k for k in order if params[k]["light_text"]]
    dark = [k for k in order if not params[k]["light_text"]]
    scrim_lines = "\n".join(f"        case .{k}: {params[k]['scrim']}" for k in order)
    title_lines = "\n".join(f"        case .{k}: .scene{k[0].upper() + k[1:]}" for k in order)

    def pal(k):
        p = params[k]
        text = LIGHT_TEXT if p["light_text"] else DARK_TEXT
        return f"        case .{k}: (0x{p['background']:06X}, 0x{p['second']:06X}, 0x{text:06X}, 0x{p['accent']:06X})"

    palette_lines = "\n".join(pal(k) for k in order)
    cases = "\n".join(f"    case {k}" for k in order)
    if light and dark:
        pref = (f"        case {', '.join('.' + k for k in light)}: true\n"
                f"        case {', '.join('.' + k for k in dark)}: false")
    else:
        pref = f"        case {', '.join('.' + k for k in order)}: {'true' if light else 'false'}"
    swift = f'''import Foundation

/// Фон-изображение вместо цветной заливки.
///
/// Выбирается там же, где наборы цвета, и тем же жестом: это второй ряд плиток
/// на экране «Вид». Одно исключает другое — выбрал картинку, цветной набор
/// перестаёт действовать, и наоборот.
///
/// Все сюжеты без людей, божеств и животных: Гималаи на рассвете, Ганга с плывущими огоньками,
/// храмовая башня, светильник, лотос, ранголи и мандала.
///
/// У каждого фона своя палитра. Она не декоративная: из неё выводятся плашки,
/// линии, приглушённый текст и заливка кнопок — всё то же, что у цветных
/// наборов. Значения посчитаны по самим изображениям (`tools/art/build_assets.py`),
/// а не подобраны на глаз.
///
/// ФАЙЛ СГЕНЕРИРОВАН `tools/art/build_assets.py` — не править руками.
public enum VerseScene: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {{
{cases}

    public var id: String {{ rawValue }}

    /// Имя набора в каталоге. Формат подставляется по месту: `-tall` для экрана
    /// и обоев, `-wide` для среднего виджета и StandBy, `-square` для остальных.
    public var asset: String {{ "bg-\\(rawValue)" }}

    /// Светлый ли текст поверх картинки.
    ///
    /// Определяется самим изображением: тёмная картинка — светлый текст.
    public var prefersLightText: Bool {{
        switch self {{
{pref}
        }}
    }}

    /// Плотность подложки под текстом.
    ///
    /// Ноль означает, что картинка держит текст сама. Значения посчитаны от
    /// яркости в той полосе, где реально лежит стих: подложка доводит контраст до
    /// 4,5:1 — порога, ниже которого текст на светлом участке перестаёт
    /// читаться. Подложка не сплошная, а сгущается только в этой полосе, иначе
    /// картинка гаснет целиком и смысл её теряется.
    public var scrim: Double {{
        switch self {{
{scrim_lines}
        }}
    }}

    /// Полоса, в которой подложка держится на полную силу, в долях высоты
    /// экрана. Совпадает с местом ссылки, стиха и плашки контекста.
    public static let textBand: ClosedRange<Double> = 0.27...0.67

    public var titleKey: L10n.Key {{
        switch self {{
{title_lines}
        }}
    }}

    /// Бесплатны только «Гималаи» — самый спокойный фон. Остальные за подпиской:
    /// это и есть тот платный набор, ради которого фоны затевались.
    public var isPremium: Bool {{ self != .himalaya }}

    /// Те же четыре цвета, что у цветного набора. `background` здесь не рисуется
    /// (сверху лежит картинка), но задаёт светлоту для плашек и кнопок.
    public var palette: (background: UInt32, second: UInt32, text: UInt32, accent: UInt32) {{
        switch self {{
{palette_lines}
        }}
    }}
}}
'''
    path = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamCore", "VerseScene.swift")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(swift)

    # точки фокуса — в Background.swift
    focus_lines = "\n".join(
        f"        case .{k}: UnitPoint(x: {params[k]['focus'][0]}, y: {params[k]['focus'][1]})" for k in order)
    bg_path = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamUI", "Background.swift")
    with open(bg_path, encoding="utf-8", newline="") as f:
        text = f.read()
    start = text.index("extension VerseScene {")
    end = text.index("/// Затемнение под строкой состояния")
    block = f'''extension VerseScene {{
    /// Где на картинке сюжет. Эта точка остаётся в кадре, когда экран режет
    /// картинку.
    ///
    /// У Гималаев и храма сюжет стоит низко (гребни, силуэт), у дии — выше
    /// середины. Новый фон без точки фокуса не соберётся — здесь исчерпывающий
    /// перебор, а не значение по умолчанию. Те же точки использует
    /// `tools/art/build_assets.py`, когда режет квадрат и полосу.
    var focus: UnitPoint {{
        switch self {{
{focus_lines}
        }}
    }}
}}

'''
    with open(bg_path, "w", encoding="utf-8", newline="") as f:
        f.write(text[:start] + block + text[end:])


# ── иконки ──────────────────────────────────────────────────────────────────

def build_icons():
    # старые наборы иконок убираем целиком
    for entry in os.listdir(APPICONS):
        if entry.endswith(".appiconset"):
            shutil.rmtree(os.path.join(APPICONS, entry))
    for key in ICON_KEYS:
        t = time.time()
        img = icons.ICONS[key](1024)
        write_appicon("AppIcon" if key == "default" else key, img)
        write_imageset(f"icon-{key}", f"icon-{key}.jpg", img.resize((512, 512), Image.LANCZOS), quality=88)
        print(f"  иконка {key:8s} ({time.time() - t:.1f} с)")


# ── арт онбординга ──────────────────────────────────────────────────────────

def build_onboarding_art():
    write_imageset("hero", "hero.jpg", icons.hero(1170), quality=90)
    write_imageset("done", "done.jpg", icons.done(1032), quality=88)
    write_imageset("gift", "gift.jpg", icons.gift(1032), quality=88)
    for key, fn in (("comfort", icons.goal_comfort), ("daily", icons.goal_daily),
                    ("feed", icons.goal_feed), ("beauty", icons.goal_beauty)):
        write_imageset(f"goal-{key}", f"goal-{key}.jpg", fn(384), quality=92)
    write_imageset("hourglass", "hourglass.png", icons.hourglass(372), fmt="PNG")
    print("  арт онбординга: hero, done, gift, goal-×4, hourglass")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(MEDIA, exist_ok=True)
    os.makedirs(APPICONS, exist_ok=True)
    # каталог Media.xcassets: Contents.json и всё прочее оставляем, наборы изображений пересобираем
    for name in os.listdir(MEDIA):
        if name.endswith(".imageset"):
            shutil.rmtree(os.path.join(MEDIA, name))
    params = build_scenes()
    write_scene_swift(params)
    build_icons()
    build_onboarding_art()
    print("готово")


if __name__ == "__main__":
    main()
