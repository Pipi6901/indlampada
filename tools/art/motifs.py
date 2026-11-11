# -*- coding: utf-8 -*-
"""Мотивы Deepam, которые повторяются на фонах, иконках и в онбординге: светильник (дия), лотос, мандала,
храм (гопурам). Каждый рисуется на `hart.Canvas` и задаётся в дизайнерских пикселях кадра шириной 1320."""
import math
import random

import numpy as np

from hart import Canvas, circle, ellipse, flame, lingrad, mix, petal, radgrad, ramp, rgb

# ── палитра ─────────────────────────────────────────────────────────────────
PLUM_0 = 0x0E0914
PLUM_1 = 0x1A1424
PLUM_2 = 0x2E2140
PLUM_3 = 0x4A2B58
MAUVE = 0x7A3F6D
ROSE = 0xB9566B
EMBER = 0xE8803A
SAFFRON = 0xF4A340
GOLD = 0xFFC95C
CREAM = 0xFFF1D0


# ── дия ─────────────────────────────────────────────────────────────────────

def diya(cv: Canvas, cx, rim_y, size, lit=True, halo=1.0, flame_scale=1.0, sway=0.05, tone="clay"):
    """Глиняный светильник с пламенем.

    `size` — ширина чаши в дизайнерских пикселях, `rim_y` — высота кромки в пикселях кадра, `halo` — сила
    свечения вокруг (0 — без него), `tone`: «clay» — тёплая терракота, «gold» — металл."""
    s = cv.px(size)
    u = cv.u
    cx, rim_y = cv.px(cx), cv.px(rim_y)
    wick_x = cx - 0.015 * s
    fh, fw = 0.74 * s * flame_scale, 0.33 * s * flame_scale
    base_y = rim_y - 0.012 * s

    if lit and halo > 0:
        cv.gauss_glow(cx, base_y - fh * 0.40, fh * 0.62, 0xFF7A22, 0.36 * halo)
        cv.gauss_glow(cx, base_y - fh * 0.40, fh * 1.5, 0xD8501E, 0.13 * halo)
        cv.gauss_glow(cx, rim_y + 0.06 * s, s * 0.62, 0xFFA040, 0.12 * halo, ry=0.5)

    # тень под чашей
    cv.poly(ellipse(cx, rim_y + 0.40 * s, 0.46 * s, 0.045 * s), 0x000000, 0.35, blur=u * 14 * size / 500)

    if tone == "gold":
        c_top, c_mid, c_bot, c_hi = 0xFFE29A, 0xD9983A, 0x6E3A14, 0xFFF3C8
    else:
        c_top, c_mid, c_bot, c_hi = 0xE8924A, 0xB4501F, 0x4A150C, 0xFFD59A

    # чаша: нижняя половина эллипса + носик слева
    # одним контуром: правый край кромки → дно → левый бок → носик → верхняя кромка, чтобы заливка была сплошной
    theta_end = math.pi - 0.62
    bowl = [(cx + 0.5 * s * math.cos(a), rim_y + 0.36 * s * math.sin(a) ** 0.92)
            for a in np.linspace(0, theta_end, 52)]
    bowl += [(cx - 0.50 * s, rim_y + 0.14 * s), (cx - 0.60 * s, rim_y + 0.07 * s), (cx - 0.66 * s, rim_y - 0.01 * s),
             (cx - 0.705 * s, rim_y - 0.108 * s), (cx - 0.60 * s, rim_y - 0.055 * s), (cx - 0.52 * s, rim_y - 0.012 * s),
             (cx - 0.40 * s, rim_y), (cx + 0.5 * s, rim_y)]
    spout = []
    foot = [(cx - 0.17 * s, rim_y + 0.32 * s), (cx + 0.17 * s, rim_y + 0.32 * s),
            (cx + 0.22 * s, rim_y + 0.415 * s), (cx - 0.22 * s, rim_y + 0.415 * s)]
    body_fill = lingrad((cx, rim_y - 0.05 * s), (cx, rim_y + 0.38 * s),
                        [(0.0, c_top), (0.32, c_mid), (1.0, c_bot)])
    cv.poly([foot], lingrad((cx, rim_y + 0.3 * s), (cx, rim_y + 0.42 * s), [(0, c_bot), (1, 0x3A1209)]))
    cv.poly([bowl], body_fill)

    # свет от пламени на боках чаши и блик слева
    cv.poly([bowl], radgrad(cx, rim_y, 0.62 * s, [(0.0, 0xFFC070), (1.0, c_bot)]), 0.28 if lit else 0.0, mode="add")
    # блик по левому боку чаши
    cv.draw(lambda d, T, ss: d.arc([*T(cx - 0.425 * s, rim_y - 0.30 * s), *T(cx + 0.425 * s, rim_y + 0.30 * s)],
                                   start=108, end=158, fill=255, width=max(1, int(0.022 * s * ss))),
            c_hi, (cx - 0.55 * s, rim_y - 0.1 * s, cx + 0.55 * s, rim_y + 0.45 * s), 0.55, blur=0.006 * s)
    # тень на правом боку: объём
    cv.poly([[(cx + 0.5 * s * math.cos(a), rim_y + 0.36 * s * math.sin(a) ** 0.92) for a in np.linspace(-0.0, 1.35, 30)]
             + [(cx + 0.12 * s, rim_y + 0.05 * s)]], 0x1C0804, 0.42, blur=0.04 * s)
    # орнамент: пояс из точек по дуге
    dots = []
    for k in range(-5, 6):
        t = k / 5.0
        x = cx + 0.37 * s * t
        y = rim_y + 0.16 * s + 0.15 * s * (1 - math.sqrt(max(0.0, 1 - (0.74 * t) ** 2)))
        dots.append(circle(x, y, 0.011 * s, 14))
    cv.poly(dots, 0xFFE0A0, 0.65, ss=4)

    # кромка и масло внутри
    cv.poly(ellipse(cx, rim_y, 0.5 * s, 0.075 * s), 0xFFD79A, 0.95, ss=4)
    cv.poly(ellipse(cx, rim_y + 0.006 * s, 0.465 * s, 0.058 * s), 0x2A0E07, 1.0, ss=4)
    if lit:
        cv.poly(ellipse(cx, rim_y + 0.004 * s, 0.30 * s, 0.040 * s), 0xFF9A3C, 0.50, blur=0.03 * s, mode="add")
    # фитиль
    cv.poly([[(wick_x - 0.014 * s, base_y + 0.005 * s), (wick_x + 0.014 * s, base_y + 0.005 * s),
              (wick_x + 0.009 * s, base_y - 0.07 * s), (wick_x - 0.009 * s, base_y - 0.07 * s)]], 0x1A0A06, 1.0, ss=4)

    if lit:
        _flame_px(cv, wick_x, base_y - 0.045 * s, fh, fw, sway)
    return cv


def flame_at(cv: Canvas, cx, base_y, height, width, sway=0.05, intensity=1.0):
    """Пламя в три слоя, всё в дизайнерских пикселях."""
    return _flame_px(cv, cv.px(cx), cv.px(base_y), cv.px(height), cv.px(width), sway, intensity)


def _flame_px(cv: Canvas, cx, base_y, height, width, sway=0.05, intensity=1.0):
    """Пламя в три слоя и яркий белый стержень; размеры — в пикселях кадра."""
    soft = max(0.8, height * 0.012)
    outer = flame(cx, base_y, height, width, sway)
    cv.poly([outer], lingrad((cx, base_y), (cx, base_y - height), [(0, 0xFF6A12), (0.55, 0xFF9A24), (1, 0xFFC040)]),
            0.96 * intensity, blur=soft)
    mid = flame(cx - width * 0.01, base_y - height * 0.03, height * 0.74, width * 0.64, sway * 0.7)
    cv.poly([mid], lingrad((cx, base_y), (cx, base_y - height * 0.75), [(0, 0xFFB43C), (1, 0xFFE7A0)]),
            0.97 * intensity, blur=soft * 0.9)
    core = flame(cx - width * 0.012, base_y - height * 0.055, height * 0.46, width * 0.34, sway * 0.4)
    cv.poly([core], lingrad((cx, base_y), (cx, base_y - height * 0.5), [(0, 0xFFF0C2), (1, 0xFFFDF2)]),
            0.98 * intensity, blur=soft * 0.7)
    # синеватая подошва у фитиля
    cv.poly([ellipse(cx, base_y - height * 0.02, width * 0.16, height * 0.035)], 0x6E86FF, 0.35 * intensity,
            blur=soft * 1.2, mode="add")
    cv.gauss_glow(cx, base_y - height * 0.32, height * 0.34, 0xFFC474, 0.55 * intensity)
    return cv
