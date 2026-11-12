# -*- coding: utf-8 -*-
"""Иконки приложения (1024×1024) и арт онбординга. Каждая функция принимает ширину кадра в пикселях и
возвращает `PIL.Image`; дизайн — на сетке 1024 (иконки) или по ширине кадра (плакаты), поэтому в любом масштабе
картинка одна и та же. Всё без людей, божеств и животных."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from hart import Canvas, circle, ellipse, lingrad, mix, petal, radgrad, ramp, rgb  # noqa: E402
import motifs  # noqa: E402
import motifs2  # noqa: E402
from motifs import AMBER, CORAL, CREAM, CRIMSON, EMBER, GARNET_0, GARNET_1, GARNET_2, GARNET_3, GOLD  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
FONT = os.path.join(ROOT, "DeepamCore", "Sources", "DeepamUI", "Resources", "Fonts", "TiroDevanagariSanskrit-Regular.ttf")


def _square(w, fill=GARNET_1):
    return Canvas(w, w, fill, design=1024.0)


# ── иконки ──────────────────────────────────────────────────────────────────

def icon_default(w=1024):
    """Главная иконка: светильник с пламенем на тёмно-красном фоне."""
    cv = _square(w)
    c = cv.px(512)
    cv.rgrad(c, cv.px(430), cv.px(820), [(0.0, 0x7E1624), (0.5, 0x3E0910), (1.0, 0x16040A)])
    # тонкие золотые кольца за пламенем — как круги на воде от лампы
    for r_, a_ in ((250, 0.16), (330, 0.11), (415, 0.07)):
        cv.draw(lambda d, T, ss, r_=r_: d.ellipse([*T(cv.px(548) - cv.px(r_), cv.px(440) - cv.px(r_)),
                                                   *T(cv.px(548) + cv.px(r_), cv.px(440) + cv.px(r_))],
                                                  outline=255, width=max(1, int(cv.px(2.2) * ss))),
                0xFFC878, (0, 0, cv.w, cv.h), a_, mode="add")
    motifs.diya(cv, 548, 700, 540, halo=0.7, flame_scale=1.0)
    cv.sparkles([(cv.px(250), cv.px(300), 15), (cv.px(790), cv.px(250), 19), (cv.px(850), cv.px(520), 11),
                 (cv.px(190), cv.px(560), 10), (cv.px(700), cv.px(150), 9)], alpha=0.85)
    return cv.to_image(1)


def icon_night(w=1024):
    """«Ночь»: тот же светильник под звёздным небом."""
    cv = _square(w, 0x260609)
    cv.vgrad([(0.0, 0x12040A), (0.45, 0x2E0A12), (0.75, 0x4E0E18), (1.0, 0x2A090F)])
    cv.stars(260, 0.70, seed=12, sizes=(0.8, 2.0), alpha=(0.3, 1.0), tint=0xFFF1DC, bias=1.3, big=7)
    # млечный путь
    yy, xx = np.mgrid[0:cv.h, 0:cv.w].astype(np.float32)
    d = np.abs((xx / cv.w - 0.2) * 0.8 + (yy / cv.h) * 0.9 - 0.45)
    cv.add(0xEFB3A7, np.exp(-(d / 0.09) ** 2) * 0.12 * (yy < cv.h * 0.7))
    cv.gauss_glow(cv.px(530), cv.px(760), cv.px(260), 0xB02A24, 0.24, ry=0.8)
    motifs.diya(cv, 530, 770, 400, halo=0.85)
    return cv.to_image(2)


def icon_lotus(w=1024):
    cv = _square(w)
    cv.rgrad(cv.px(512), cv.px(600), cv.px(820), [(0.0, 0x6A1420), (0.55, 0x34090F), (1.0, 0x14050A)])
    motifs2.lotus(cv, 512, 760, 1000, halo=0.7, halo_color=0xD83A26)
    cv.sparkles([(cv.px(200), cv.px(260), 13), (cv.px(830), cv.px(220), 16), (cv.px(880), cv.px(470), 10),
                 (cv.px(150), cv.px(520), 9)], color=0xF7D7D0, alpha=0.8)
    return cv.to_image(3)


def _glyph_mask(text, size, w):
    """Маска глифа по центру кадра w×w (Tiro Devanagari Sanskrit); возвращает массив 0…1 и левый верхний угол."""
    f = ImageFont.truetype(FONT, int(size))
    box = f.getbbox(text)
    gw, gh = box[2] - box[0], box[3] - box[1]
    im = Image.new("L", (gw + 8, gh + 8), 0)
    ImageDraw.Draw(im).text((4 - box[0], 4 - box[1]), text, font=f, fill=255)
    return np.asarray(im, np.float32) / 255.0, gw + 8, gh + 8


def icon_om(w=1024):
    cv = _square(w)
    cv.rgrad(cv.px(512), cv.px(470), cv.px(820), [(0.0, 0xE8782A), (0.35, 0xB02A1F), (0.70, 0x5A0F18), (1.0, 0x240609)])
    # лучи
    yy, xx = np.mgrid[0:cv.h, 0:cv.w].astype(np.float32)
    ang = np.arctan2(xx - cv.px(512), -(yy - cv.px(480)))
    rays = (0.5 + 0.5 * np.cos(ang * 18)) ** 5
    dist = np.sqrt((xx - cv.px(512)) ** 2 + (yy - cv.px(480)) ** 2) / cv.w
    cv.add(0xFFC070, rays * np.exp(-dist * 2.0) * 0.16)
    # кольцо
    cv.draw(lambda d, T, ss: d.ellipse([*T(cv.px(512 - 400), cv.px(480 - 400)), *T(cv.px(512 + 400), cv.px(480 + 400))],
                                       outline=255, width=max(1, int(cv.px(5) * ss))),
            0xFFF0CC, (0, 0, cv.w, cv.h), 0.55, mode="add")
    cv.draw(lambda d, T, ss: d.ellipse([*T(cv.px(512 - 372), cv.px(480 - 372)), *T(cv.px(512 + 372), cv.px(480 + 372))],
                                       outline=255, width=max(1, int(cv.px(2.5) * ss))),
            0xFFF0CC, (0, 0, cv.w, cv.h), 0.35, mode="add")
    # знак «ॐ»
    m, gw, gh = _glyph_mask("ॐ", cv.px(640), cv.w)
    x0, y0 = int(cv.px(512) - gw / 2), int(cv.px(488) - gh / 2)
    from scipy.ndimage import gaussian_filter
    shadow = gaussian_filter(m, cv.px(14))
    cv.over(0x5A1208, shadow * 0.45, x0, y0 + int(cv.px(8)))
    cv.over(0xFFF6E0, m, x0, y0)
    cv.gauss_glow(cv.px(512), cv.px(488), cv.px(300), 0xFFE2A0, 0.18)
    return cv.to_image(4)


def icon_dawn(w=1024):
    cv = _square(w)
    hy = 0.60
    cv.vgrad([(0.0, 0x1E060C), (0.30, 0x5A1018), (0.48, 0xA82822), (0.58, 0xE46A24), (hy, 0xF59A3A),
              (hy + 0.005, 0xC8431E), (0.80, 0x6A1219), (1.0, 0x2E070C)])
    cv.stars(80, 0.30, seed=14, sizes=(0.7, 1.6), alpha=(0.3, 0.9), bias=1.0)
    cx, cy = cv.px(512), cv.px(hy * 1024)
    cv.gauss_glow(cx, cy, cv.px(420), 0xFF8A3A, 0.34, ry=0.7)
    disc = [(cx + cv.px(200) * math.cos(a), cy - cv.px(200) * math.sin(a)) for a in np.linspace(0, math.pi, 60)]
    cv.poly([disc], lingrad((cx, cy - cv.px(200)), (cx, cy), [(0, 0xFFD27A), (1, 0xFF9E3C)]), 1.0, ss=4, blur=cv.px(1.5))
    cv.gauss_glow(cx, cy, cv.px(250), 0xFFB050, 0.20, ry=0.8)
    # дальний берег
    ys = np.full(cv.w, cy, np.float32) - cv.px(10) * (fbm_like(cv.w, 3) - 0.3)
    cv.ridge(ys, 0x2A0609)
    # отражение: полосы, сужающиеся книзу
    for k in range(18):
        t = k / 17
        y = cy + cv.px(14) + t * cv.px(300)
        half = cv.px(210) * (1 - 0.55 * t) * (0.7 + 0.3 * math.sin(k * 2.1))
        hgt = cv.px(5 + 6 * t)
        cv.poly([[(cx - half, y), (cx + half, y), (cx + half * 0.9, y + hgt), (cx - half * 0.9, y + hgt)]],
                0xFF9A48, 0.50 * (1 - 0.7 * t), ss=3, blur=cv.px(1.2), mode="add")
    return cv.to_image(5)


def fbm_like(n, seed):
    from hart import fbm
    return fbm(n, seed, base=10, octaves=4)


def icon_temple(w=1024):
    cv = _square(w)
    cv.vgrad([(0.0, 0x1E060C), (0.35, 0x5A101A), (0.55, 0xAE2820), (0.70, 0xDA5C1E), (0.85, 0xE67A26), (1.0, 0xE67A26)])
    cv.stars(60, 0.30, seed=15, sizes=(0.7, 1.5), alpha=(0.3, 0.9), bias=1.0)
    cv.gauss_glow(cv.px(512), cv.px(650), cv.px(380), 0xFF8A3A, 0.38, ry=0.8)
    cv.poly([circle(cv.px(512), cv.px(630), cv.px(170), 80)], 0xFFB65A, 0.96, ss=4, blur=cv.px(1.5))
    motifs2.gopuram(cv, 512, 1000, 470, 790, color=0x200508, tiers=8, windows=0xFFB24A)
    return cv.to_image(6)


def icon_mandala(w=1024):
    cv = _square(w)
    cv.rgrad(cv.px(512), cv.px(512), cv.px(780), [(0.0, 0x7A1522), (0.55, 0x420A12), (1.0, 0x1A0408)])
    cv.gauss_glow(cv.px(512), cv.px(512), cv.px(250), 0xF5A04A, 0.30)
    motifs2.mandala(cv, 512, 512, 440, color=0xF4C860, alpha=0.95, lines=3.6)
    return cv.to_image(7)


def icon_light(w=1024):
    cv = _square(w)
    cv.rgrad(cv.px(512), cv.px(512), cv.px(800), [(0.0, 0x8A1A26), (0.55, 0x4A0C14), (1.0, 0x1A0408)])
    yy, xx = np.mgrid[0:cv.h, 0:cv.w].astype(np.float32)
    ang = np.arctan2(xx - cv.px(512), -(yy - cv.px(512)))
    long_ = (0.5 + 0.5 * np.cos(ang * 16)) ** 14
    short = (0.5 + 0.5 * np.cos(ang * 16 + math.pi)) ** 22
    dist = np.sqrt((xx - cv.px(512)) ** 2 + (yy - cv.px(512)) ** 2) / cv.w
    cv.add(0xFFD27A, long_ * np.exp(-dist * 1.4) * 0.80)
    cv.add(0xFFB650, short * np.exp(-dist * 2.4) * 0.45)
    cv.gauss_glow(cv.px(512), cv.px(512), cv.px(190), 0xFFC060, 0.9)
    cv.poly([circle(cv.px(512), cv.px(512), cv.px(92), 80)], 0xFFF4D8, 1.0, ss=4, blur=cv.px(1.0))
    cv.draw(lambda d, T, ss: d.ellipse([*T(cv.px(512 - 150), cv.px(512 - 150)), *T(cv.px(512 + 150), cv.px(512 + 150))],
                                       outline=255, width=max(1, int(cv.px(3) * ss))),
            0xFFE2A8, (0, 0, cv.w, cv.h), 0.5, mode="add")
    return cv.to_image(8)


ICONS = {
    "default": icon_default,
    "night": icon_night,
    "lotus": icon_lotus,
    "om": icon_om,
    "dawn": icon_dawn,
    "temple": icon_temple,
    "mandala": icon_mandala,
    "light": icon_light,
}


# ── арт онбординга ──────────────────────────────────────────────────────────

def _poster(w, h, top, bottom, centre_y, glow_color=0xFF8A2E):
    cv = Canvas(w, h, top, design=float(w))
    cv.vgrad([(0.0, top), (0.55, mix(top, bottom, 0.6)), (1.0, bottom)])
    return cv


def hero(w=1170):
    """Первый экран онбординга: большой светильник в верхней половине, внизу тёмное поле под текст."""
    h = int(round(w * 2532 / 1170))
    cv = Canvas(w, h, 0x2B0D10, design=1170.0)
    cv.vgrad([(0.0, 0x2E0C13), (0.35, 0x20090E), (0.70, 0x150709), (1.0, 0x0C0406)])
    cv.gauss_glow(w * 0.5, h * 0.30, w * 0.65, 0x9A2A22, 0.14, ry=1.1)
    # мандала за светильником — едва видимая
    motifs2.mandala(cv, 585, 0.30 * 2532, 560, color=0xF0B860, alpha=0.18, lines=2.4)
    for r_, a_ in ((300, 0.12), (400, 0.08)):
        cv.draw(lambda d, T, ss, r_=r_: d.ellipse([*T(w * 0.5 - cv.px(r_), h * 0.30 - cv.px(r_)),
                                                   *T(w * 0.5 + cv.px(r_), h * 0.30 + cv.px(r_))],
                                                  outline=255, width=max(1, int(cv.px(2) * ss))),
                0xFFC878, (0, 0, w, h), a_, mode="add")
    motifs.diya(cv, 585 + 20, 0.335 * 2532, 640, halo=0.9)
    rnd = np.random.default_rng(3)
    pts = [(w * (0.15 + 0.7 * rnd.random()), h * (0.10 + 0.34 * rnd.random()), 6 + 12 * rnd.random()) for _ in range(20)]
    cv.sparkles(pts, alpha=0.75)
    return cv.to_image(21)


def done(w=1032):
    h = int(round(w * 2256 / 1032))
    cv = Canvas(w, h, 0x2B0D10, design=1032.0)
    cv.vgrad([(0.0, 0x34101A), (0.5, 0x20090E), (1.0, 0x0E0406)])
    cv.gauss_glow(w * 0.5, h * 0.36, w * 0.60, 0xA82A24, 0.14, ry=1.0)
    motifs2.lotus(cv, 516, 0.40 * 2256, 760, halo=0.8, halo_color=0xD83A26)
    rnd = np.random.default_rng(4)
    pts = [(w * (0.15 + 0.7 * rnd.random()), h * (0.10 + 0.36 * rnd.random()), 5 + 11 * rnd.random()) for _ in range(34)]
    cv.sparkles(pts, color=0xF9E2DE, alpha=0.8)
    return cv.to_image(22)


def gift(w=1032):
    h = int(round(w * 2256 / 1032))
    cv = Canvas(w, h, 0x2B0D10, design=1032.0)
    cv.vgrad([(0.0, 0x32101A), (0.5, 0x1F090D), (1.0, 0x0C0406)])
    # золотые лучи
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ang = np.arctan2(xx - w * 0.5, -(yy - h * 0.36))
    rays = (0.5 + 0.5 * np.cos(ang * 12)) ** 8
    dist = np.sqrt((xx - w * 0.5) ** 2 + (yy - h * 0.36) ** 2) / w
    cv.add(0xFFC060, rays * np.exp(-dist * 1.6) * 0.16)
    cv.gauss_glow(w * 0.5, h * 0.36, w * 0.5, 0xF0A040, 0.22, ry=1.0)
    motifs.diya(cv, 516 + 18, 0.40 * 2256, 600, halo=0.95)
    rnd = np.random.default_rng(5)
    pts = [(w * rnd.random(), h * (0.06 + 0.5 * rnd.random()), 5 + 12 * rnd.random()) for _ in range(44)]
    cv.sparkles(pts, color=0xFFD890, alpha=0.8)
    return cv.to_image(23)


# значки ответов 384×384: плитка с тёмным градиентом и знаком по центру
def _goal_canvas(w):
    cv = Canvas(w, w, 0x460B11, design=384.0)
    cv.rgrad(cv.px(192), cv.px(170), cv.px(300), [(0.0, 0x5A1A24), (0.6, 0x34101A), (1.0, 0x1E080D)])
    return cv


def goal_comfort(w=384):
    cv = _goal_canvas(w)
    # сердце
    pts = []
    for t in np.linspace(0, 2 * math.pi, 120):
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cv.px(192 + x * 6.4), cv.px(176 + y * 6.4)))
    cv.gauss_glow(cv.px(192), cv.px(180), cv.px(130), 0xEA817F, 0.30)
    cv.poly([pts], lingrad((cv.px(192), cv.px(90)), (cv.px(192), cv.px(290)), [(0, 0xEDA99C), (1, 0xE0403E)]), 1.0, ss=4,
            blur=0.4)
    motifs._flame_px(cv, cv.px(192), cv.px(214), cv.px(104), cv.px(52), 0.05)
    return cv.to_image(31)


def goal_daily(w=384):
    cv = _goal_canvas(w)
    cx, cy = cv.px(192), cv.px(226)
    cv.gauss_glow(cx, cy, cv.px(150), 0xFFA040, 0.45, ry=0.9)
    for k in range(9):
        a = math.radians(180 + k * 22.5)
        r0, r1 = cv.px(88), cv.px(128 if k % 2 == 0 else 112)
        cv.poly([[(cx + r0 * math.cos(a - 0.05), cy + r0 * math.sin(a - 0.05)),
                  (cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
                  (cx + r0 * math.cos(a + 0.05), cy + r0 * math.sin(a + 0.05))]], 0xFFC860, 0.95, ss=4)
    cv.poly([[(cx + cv.px(74) * math.cos(a), cy - cv.px(74) * math.sin(a)) for a in np.linspace(0, math.pi, 50)]],
            lingrad((cx, cy - cv.px(74)), (cx, cy), [(0, 0xFFE9A8), (1, 0xFFA84A)]), 1.0, ss=4)
    cv.poly([[(cv.px(48), cy), (cv.px(336), cy), (cv.px(336), cy + cv.px(5)), (cv.px(48), cy + cv.px(5))]], 0xFFD890, 0.8, ss=3)
    for k, wd in enumerate((220, 160, 100)):
        y = cy + cv.px(18 + k * 14)
        cv.poly([[(cx - cv.px(wd / 2), y), (cx + cv.px(wd / 2), y), (cx + cv.px(wd / 2), y + cv.px(4)), (cx - cv.px(wd / 2), y + cv.px(4))]],
                0xFFC070, 0.45 - 0.1 * k, ss=3)
    return cv.to_image(32)


def goal_feed(w=384):
    cv = _goal_canvas(w)
    x0, y0, x1, y1 = cv.px(118), cv.px(52), cv.px(266), cv.px(332)
    r = cv.px(26)

    def rr(d, T, ss):
        d.rounded_rectangle([*T(x0, y0), *T(x1, y1)], radius=r * ss, outline=255, width=max(1, int(cv.px(7) * ss)))
    cv.draw(rr, 0xF7DAD5, (x0 - 6, y0 - 6, x1 + 6, y1 + 6), 0.95, ss=3)
    cv.poly([[(x0 + cv.px(5), y0 + cv.px(5)), (x1 - cv.px(5), y0 + cv.px(5)), (x1 - cv.px(5), y1 - cv.px(5)), (x0 + cv.px(5), y1 - cv.px(5))]],
            0x30090D, 0.0)
    cv.gauss_glow(cv.px(192), cv.px(206), cv.px(110), 0xFF8A2E, 0.32)
    motifs._flame_px(cv, cv.px(192), cv.px(240), cv.px(110), cv.px(52), 0.05)
    cv.poly([[(cv.px(170), cv.px(252)), (cv.px(214), cv.px(252)), (cv.px(206), cv.px(266)), (cv.px(178), cv.px(266))]], 0xC9612E, 1.0, ss=4)
    cv.poly([[(cv.px(176), cv.px(68)), (cv.px(208), cv.px(68)), (cv.px(208), cv.px(76)), (cv.px(176), cv.px(76))]], 0xF7DAD5, 0.7, ss=4)
    return cv.to_image(33)


def goal_beauty(w=384):
    cv = _goal_canvas(w)
    motifs2.lotus(cv, 192, 262, 330, halo=1.0, water=False)
    cv.sparkles([(cv.px(78), cv.px(92), 12), (cv.px(312), cv.px(110), 9), (cv.px(292), cv.px(58), 7)], color=0xF8DDD7, alpha=0.9)
    return cv.to_image(34)


# песочные часы: рисуются на двух фонах, прозрачность восстанавливается по разности
def _hourglass_on(fill, w):
    cv = Canvas(w, w, fill, design=372.0)
    cx = cv.px(186)
    # свечение
    cv.gauss_glow(cx, cv.px(186), cv.px(120), 0xFFA040, 0.20)

    def bulb(top, sign):
        pts = []
        for t in np.linspace(0, 1, 40):
            hw = 88 * (1 - t) ** 0.72 + 7
            pts.append((hw, 64 + 122 * t))
        return pts
    top = bulb(0, 1)
    glass_top = [(cx + cv.px(x), cv.px(y)) for x, y in top] + [(cx - cv.px(x), cv.px(y)) for x, y in top[::-1]]
    glass_bot = [(cx + cv.px(x), cv.px(372 - y)) for x, y in top] + [(cx - cv.px(x), cv.px(372 - y)) for x, y in top[::-1]]
    cv.poly([glass_top, glass_bot], 0xF2C0B6, 0.20, ss=4)
    # песок сверху (ниже уровня 112) и холм внизу
    sand_top = [(cx + cv.px(x), cv.px(y)) for x, y in top if y >= 112] + [(cx - cv.px(x), cv.px(y)) for x, y in top[::-1] if y >= 112]
    cv.poly([sand_top], lingrad((cx, cv.px(112)), (cx, cv.px(186)), [(0, 0xFFD27A), (1, 0xF29A3A)]), 0.95, ss=4)
    mound = [(cx - cv.px(78), cv.px(308)), (cx - cv.px(40), cv.px(278)), (cx, cv.px(256)), (cx + cv.px(40), cv.px(278)),
             (cx + cv.px(78), cv.px(308))]
    cv.poly([mound], lingrad((cx, cv.px(256)), (cx, cv.px(308)), [(0, 0xFFD27A), (1, 0xE88A34)]), 0.95, ss=4)
    cv.poly([[(cx - cv.px(2.2), cv.px(186)), (cx + cv.px(2.2), cv.px(186)), (cx + cv.px(1.4), cv.px(262)), (cx - cv.px(1.4), cv.px(262))]],
            0xFFC060, 0.95, ss=4)
    # контур стекла
    def outline(d, T, ss):
        for sgn in (1, -1):
            d.line([T(cx + sgn * cv.px(x), cv.px(y)) for x, y in top], fill=255, width=max(1, int(cv.px(4) * ss)), joint="curve")
            d.line([T(cx + sgn * cv.px(x), cv.px(372 - y)) for x, y in top], fill=255, width=max(1, int(cv.px(4) * ss)), joint="curve")
    cv.draw(outline, 0xF2D48A, (0, 0, w, w), 0.95, ss=3)
    # крышки и стойки
    for y0, y1 in ((30, 58), (314, 342)):
        cv.poly([[(cx - cv.px(112), cv.px(y0)), (cx + cv.px(112), cv.px(y0)), (cx + cv.px(112), cv.px(y1)), (cx - cv.px(112), cv.px(y1))]],
                lingrad((0, cv.px(y0)), (0, cv.px(y1)), [(0, 0xFFE29A), (1, 0xC98A30)]), 1.0, ss=4)
    for sx in (-100, 100):
        cv.poly([[(cx + cv.px(sx - 4), cv.px(58)), (cx + cv.px(sx + 4), cv.px(58)), (cx + cv.px(sx + 4), cv.px(314)), (cx + cv.px(sx - 4), cv.px(314))]],
                0xD9A446, 0.9, ss=4)
    return cv


def hourglass(w=372):
    """RGBA: песочные часы на прозрачном фоне (прозрачность — по разности двух прорисовок на чёрном и белом)."""
    black = np.clip(_hourglass_on(0x000000, w).a, 0, 1)
    white = np.clip(_hourglass_on(0xFFFFFF, w).a, 0, 1)
    alpha = np.clip(1 - (white - black).mean(-1), 0, 1)
    color = np.where(alpha[..., None] > 1e-4, black / np.maximum(alpha[..., None], 1e-4), 0)
    out = np.dstack([np.clip(color, 0, 1), alpha])
    return Image.fromarray(np.rint(out * 255).astype(np.uint8), "RGBA")
