# -*- coding: utf-8 -*-
"""Фоны-картинки: Гималаи, Ганга, храм, дия, лотос, ранголи, мандала.

Каждая сцена — функция `scene(width)` -> PIL.Image высокого кадра (пропорции 1320×2868). Квадрат и полоса для
виджетов режутся из него вокруг точки фокуса в `build_assets.py`. Центральная полоса кадра (27–67% высоты)
оставлена спокойной: там лежит стих, и яркие детали туда не заходят; их место — верх и низ."""
import math
import os
import random
import sys

import numpy as np
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from hart import Canvas, circle, ellipse, fbm, flame, lingrad, mix, radgrad, ramp, rgb  # noqa: E402
import motifs  # noqa: E402
import motifs2  # noqa: E402
from motifs import AMBER, CORAL, CREAM, CRIMSON, EMBER, GARNET_0, GARNET_1, GARNET_2, GARNET_3, GOLD  # noqa: E402

TALL = 2868 / 1320.0


def _canvas(w):
    return Canvas(w, int(round(w * TALL)))


def _ridge(cv, base, amp, seed, peaks=(), rough=0.55, base_freq=4, octaves=6, sharp=0.8):
    """Линия гребня: по высоте на каждый столбец. `peaks` — отдельные вершины (x в долях ширины, высота в долях
    высоты кадра, полуширина в долях ширины). Острота `sharp` > 0 даёт «лезвийные» гребни горных цепей."""
    n = cv.w
    f = fbm(n, seed, base=base_freq, octaves=octaves, persistence=rough)
    ridged = 1 - np.abs(2 * f - 1)
    shape = (1 - sharp) * f + sharp * ridged
    ys = (base - amp * shape) * cv.h
    x = np.linspace(0, 1, n, dtype=np.float32)
    for px_, ph, pw in peaks:
        ys -= ph * cv.h * np.clip(1 - np.abs(x - px_) / pw, 0, 1) ** 1.35
    return ys


# ── Гималаи ─────────────────────────────────────────────────────────────────

def himalaya(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.vgrad([(0.00, 0x14050A), (0.26, 0x2C0A12), (0.46, 0x4E1019), (0.60, 0x7E1722), (0.69, 0xB02A1F),
              (0.76, 0xDC5E22), (0.82, 0xF29A38), (1.0, 0xF29A38)])
    cv.stars(260, 0.40, seed=3, sizes=(0.7, 1.6), alpha=(0.25, 0.9), big=5)
    # рассвет за хребтами
    cv.gauss_glow(w * 0.56, h * 0.775, w * 0.55, 0xFFA244, 0.60, ry=0.45)
    cv.gauss_glow(w * 0.56, h * 0.775, w * 0.20, 0xFFCF7E, 0.50, ry=0.60)
    # хребты от дальнего к ближнему
    layers = [
        # база, размах, зерно, вершины, цвет сверху, цвет снизу
        (0.690, 0.070, 11, [(0.62, 0.118, 0.20), (0.18, 0.060, 0.13), (0.92, 0.050, 0.10)], 0x9C2A1E, 0xD8662A),
        (0.740, 0.060, 12, [], 0x7A1D22, 0xA23224),
        (0.795, 0.052, 13, [], 0x4F1219, 0x6E1D22),
        (0.860, 0.046, 14, [], 0x32090F, 0x430D13),
        (0.940, 0.022, 15, [], 0x1A0508, 0x22070B),
    ]
    for base, amp, seed, peaks, c_top, c_bot in layers:
        ys = _ridge(cv, base, amp, seed, peaks, sharp=0.85 if base < 0.8 else 0.5)
        span = 0.16 * h

        def fill(X, Y, ys=ys, c_top=c_top, c_bot=c_bot, span=span):
            t = np.clip((Y - ys[X.astype(int)]) / span, 0, 1)
            return mix(c_top, c_bot, t)
        cv.ridge(ys, fill)
        # блик снега у самых вершин дальнего хребта
        if base < 0.70:
            yy = np.arange(h, dtype=np.float32)[:, None]
            band = np.clip(1 - (yy - ys[None, :]) / (0.011 * h), 0, 1) * (yy >= ys[None, :] - 1)
            cv.add(0xFFB468, band ** 1.6 * 0.30)
        # дымка между хребтами
        yy_haze = ys.min() / h
        cv.glow(w * 0.55, (yy_haze + 0.10) * h, w * 1.1, 0xE9803A, 0.14, ry=0.2, mode="over") if base < 0.9 else None
    return cv.to_image(5)


# ── Ганга ───────────────────────────────────────────────────────────────────

def ganga(w=1320):
    cv = _canvas(w)
    h = cv.h
    hy = 0.335          # линия горизонта
    cv.vgrad([(0.0, 0x150305), (0.16, 0x2E070B), (0.28, 0x520C13), (hy - 0.005, 0x691921), (hy, 0x691921),
              (hy + 0.01, 0x4B1419), (0.55, 0x30090D), (0.80, 0x1F0507), (1.0, 0x110304)])
    cv.stars(300, 0.27, seed=4, sizes=(0.6, 1.5), alpha=(0.2, 0.85), big=4)
    # млечный путь: размытая диагональная полоса
    yy, xx = np.mgrid[0:int(hy * h), 0:w].astype(np.float32)
    d = np.abs((xx / w - 0.30) * 0.9 + (yy / h - 0.0) * 1.0 - 0.18)
    band = np.exp(-(d / 0.07) ** 2) * (0.35 + 0.65 * np.random.default_rng(5).random((1, 1)))
    noise = gaussian_filter(np.random.default_rng(6).random((int(hy * h), w)).astype(np.float32), 5 * cv.u)
    band *= 0.6 + 1.6 * (noise - noise.mean()) / (noise.std() + 1e-6) * 0.2
    cv.add(0xF2BDB2, np.clip(band, 0, 1) * 0.10)
    # свет за дальним берегом
    cv.gauss_glow(w * 0.5, hy * h, w * 0.5, 0xE07A5A, 0.28, ry=0.22)

    # дальний берег: гхаты и башенки
    ys = np.full(w, hy * h, np.float32) - 4 * cv.u * (fbm(w, 21, base=12, octaves=3) - 0.4)
    cv.ridge(ys, 0x190406)
    spire_xs = [0.10, 0.27, 0.41, 0.63, 0.78, 0.92]
    for k, fx in enumerate(spire_xs):
        sw = (0.034 + 0.01 * (k % 3)) * 1320
        sh = (0.040 + 0.012 * (k % 2)) * 2868 * 0.9
        motifs2.gopuram(cv, fx * 1320, hy * 2868 + 6, sw, sh * 0.55, color=0x190406, tiers=5, windows=0xFFB864,
                        win_alpha=0.6, finials=3, portal=False)
    # огни на гхатах и их отражения
    rnd = random.Random(7)
    for _ in range(46):
        x = rnd.random() * w
        y = hy * h - rnd.random() * 5 * cv.u
        a = rnd.uniform(0.35, 0.9)
        cv.gauss_glow(x, y, cv.px(1.5), 0xFFC878, a)
        cv.gauss_glow(x, hy * h + cv.px(10), cv.px(3.0), 0xFF9A4A, a * 0.30, ry=7.0)

    # вода: горизонтальные блики, плотнее у горизонта
    rng = np.random.default_rng(8)
    water_h = h - int(hy * h)
    base = rng.random((water_h, w)).astype(np.float32)
    streak = np.zeros((water_h, w), np.float32)
    for y0, y1, sy in ((0.0, 0.22, 0.9), (0.18, 0.55, 2.2), (0.5, 1.0, 5.0)):
        a, b = int(y0 * water_h), int(y1 * water_h)
        s_ = gaussian_filter(base[a:b], (sy * cv.u, 42 * cv.u))
        s_ = (s_ - s_.mean()) / (s_.std() + 1e-6)
        wgt = np.linspace(0, 1, b - a, dtype=np.float32)[:, None]
        edge = np.minimum(np.minimum(wgt, 1 - wgt) * 4, 1) if y1 < 1 else np.minimum(wgt * 4, 1)
        streak[a:b] = np.maximum(streak[a:b], np.clip(s_ - 0.7, 0, 2) * edge)
    cv.add(0xD45B5F, streak * 0.16, 0, int(hy * h))
    # дорожка света под далёким заревом
    cv.gauss_glow(w * 0.5, hy * h + h * 0.10, w * 0.10, 0xFF9650, 0.30, ry=5.0)

    # плывущие огоньки: чем ниже, тем крупнее
    rnd = random.Random(9)
    pts = []
    for i in range(54):
        t = rnd.random() ** 0.9
        y = (hy + 0.045 + 0.915 * t)
        near = (y - hy) / (1 - hy)
        spread = 0.18 + 0.82 * near ** 0.7
        x = 0.5 + (rnd.random() - 0.5) * 1.05 * spread
        pts.append((near, x, y))
    pts.sort()
    for near, fx, fy in pts:
        s = 0.035 + 1.15 * near ** 1.5
        x, y = fx * w, fy * h
        fh = cv.px(22) * s * 2.6
        fw = fh * 0.46
        # тёплое пятно на воде и отражение столбиком
        cv.gauss_glow(x, y + fh * 0.4, fw * 3.2, 0xFF8A3A, 0.22)
        cv.gauss_glow(x, y + fh * 2.6, fw * 0.8, 0xFFA24A, 0.34, ry=5.2)
        # лодочка-листок и пламя
        cv.poly([ellipse(x, y + fh * 0.18, fw * 1.9, fw * 0.62)], 0x1E0507, 0.96, ss=4)
        cv.poly([ellipse(x, y + fh * 0.10, fw * 1.5, fw * 0.40)], 0xC4602A, 0.9, ss=4)
        motifs._flame_px(cv, x, y + fh * 0.05, fh, fw, 0.04)
        # круги от лодочки
        if near > 0.25:
            for k, a in ((1.0, 0.18), (1.6, 0.10)):
                cv.draw(lambda d, T, ss, k=k: d.ellipse([*T(x - fw * 3.4 * k, y + fh * 0.18 - fw * 0.9 * k),
                                                         *T(x + fw * 3.4 * k, y + fh * 0.18 + fw * 0.9 * k)],
                                                        outline=255, width=max(1, int(cv.px(1.8) * ss))),
                        0xFFC070, (x - fw * 5.6, y - fw, x + fw * 5.6, y + fw * 2.6), a, mode="add")
    return cv.to_image(6)


# ── Храм ────────────────────────────────────────────────────────────────────

def temple(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.vgrad([(0.00, 0x14050A), (0.26, 0x2E0A12), (0.46, 0x5A101A), (0.60, 0x8E1B22), (0.70, 0xC03A22),
              (0.79, 0xDA5C1E), (0.86, 0xE67A26), (1.0, 0xE67A26)])
    cv.stars(240, 0.36, seed=5, sizes=(0.6, 1.5), alpha=(0.2, 0.85), big=4)
    # солнце за башней
    cv.gauss_glow(w * 0.5, h * 0.735, w * 0.60, 0xFF8A3A, 0.38, ry=0.5)
    cv.poly([circle(w * 0.5, h * 0.725, w * 0.13, 90)], 0xFFB65A, 0.95, ss=3, blur=cv.px(2))
    cv.gauss_glow(w * 0.5, h * 0.725, w * 0.24, 0xFFAA4A, 0.30)
    # лучи
    ray = np.zeros((h, w), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ang = np.arctan2(xx - w * 0.5, -(yy - h * 0.725))
    rays = (0.5 + 0.5 * np.cos(ang * 22)) ** 6
    dist = np.sqrt((xx - w * 0.5) ** 2 + (yy - h * 0.725) ** 2) / w
    ray = rays * np.exp(-dist * 2.4) * (yy < h * 0.80)
    cv.add(0xFF9A3C, ray * 0.075)
    # башни: боковые и главная
    col = 0x1E0507
    motifs2.gopuram(cv, 0.12 * 1320, 0.992 * 2868, 300, 0.22 * 2868, color=col, tiers=6, windows=0xFFB24A, win_alpha=0.75,
                    finials=3)
    motifs2.gopuram(cv, 0.88 * 1320, 0.992 * 2868, 300, 0.22 * 2868, color=col, tiers=6, windows=0xFFB24A, win_alpha=0.75,
                    finials=3)
    motifs2.gopuram(cv, 0.5 * 1320, 0.992 * 2868, 560, 0.375 * 2868, color=col, tiers=9, windows=0xFFB24A,
                    win_alpha=0.9, finials=5)
    # стена с зубцами
    wall_y = 0.952 * h
    ys = np.full(w, wall_y, np.float32)
    merlon = 70 * cv.u
    for k in range(0, w, int(merlon * 1.8)):
        ys[k:k + int(merlon)] = wall_y - 22 * cv.u
    cv.ridge(ys, col)
    # окошки стены
    for k in range(9):
        fx = (k + 0.5) / 9 * w
        if abs(fx - w * 0.5) < 0.19 * w:
            continue
        cv.poly([motifs2._arch(fx, 0.985 * h, 14 * cv.u, 50 * cv.u)], 0xFFB24A, 0.8, ss=3, blur=0.5)
    return cv.to_image(7)


# ── Дия ─────────────────────────────────────────────────────────────────────

def diya_scene(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.rgrad(w * 0.5, h * 0.20, 1.25 * w, [(0.0, 0x59171C), (0.40, 0x380D11), (1.0, 0x140405)], ry=1.55)
    # боке: мягкие диски света, больше внизу
    rnd = random.Random(31)
    palette = [0xFFB45A, 0xFF8A4A, 0xFFD98A, 0xE66664]
    for i in range(70):
        r = cv.px(rnd.uniform(18, 92))
        x = rnd.random() * w
        y = (0.30 + 0.70 * rnd.random() ** 0.8) * h if rnd.random() < 0.8 else rnd.random() * 0.30 * h
        a = rnd.uniform(0.04, 0.15)
        col = palette[rnd.randrange(len(palette))]
        cv.poly([circle(x, y, r, 40)], col, a, ss=3, blur=r * 0.34, mode="add")
        if i % 4 == 0:
            cv.draw(lambda d, T, ss, x=x, y=y, r=r: d.ellipse([*T(x - r, y - r), *T(x + r, y + r)], outline=255,
                                                              width=max(1, int(cv.px(2) * ss))),
                    col, (x - r - 4, y - r - 4, x + r + 4, y + r + 4), a * 1.4, blur=0.8, mode="add")
    # светильник сверху
    motifs.diya(cv, 660, 0.205 * 2868, 560, halo=1.15)
    # парящие искры
    rnd = random.Random(33)
    sp = []
    for _ in range(26):
        sp.append((w * (0.5 + (rnd.random() - 0.5) * 0.8), h * (0.03 + rnd.random() * 0.22), rnd.uniform(5, 13)))
    cv.sparkles(sp, alpha=0.8)
    # спокойный низ: затемнение у нижнего края
    cv.glow(w * 0.5, h * 1.04, w * 1.0, 0x0E0203, 0.5, ry=0.5, mode="over")
    return cv.to_image(8)


# ── Лотос ───────────────────────────────────────────────────────────────────

def lotus_scene(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.vgrad([(0.0, 0x1C0407), (0.35, 0x3E090F), (0.62, 0x4D0B12), (0.80, 0x38080D), (1.0, 0x150305)])
    cv.gauss_glow(w * 0.5, h * 0.10, w * 0.38, 0xD0603A, 0.16, ry=0.8)
    cv.stars(120, 0.30, seed=6, sizes=(0.6, 1.4), alpha=(0.2, 0.8), big=2)
    cx, cy = w * 0.5, h * 0.885
    # круги на воде
    for k in range(14):
        rx = w * (0.16 + 0.085 * k)
        ry = rx * 0.17
        a = 0.17 * (1 - k / 15)
        cv.draw(lambda d, T, ss, rx=rx, ry=ry: d.ellipse([*T(cx - rx, cy - ry), *T(cx + rx, cy + ry)], outline=255,
                                                        width=max(1, int(cv.px(2.0) * ss))),
                0xE8905A, (cx - rx - 4, cy - ry - 4, cx + rx + 4, cy + ry + 4), a, mode="add")
    # листья кувшинки
    pads = [(0.14, 0.925, 0.34, 0.058, 0.2), (0.86, 0.905, 0.30, 0.052, -0.3), (0.30, 0.968, 0.26, 0.045, 0.1),
            (0.74, 0.972, 0.28, 0.048, -0.1), (0.05, 0.84, 0.20, 0.036, 0.0), (0.97, 0.835, 0.20, 0.036, 0.0)]
    for fx, fy, pw, ph, rot in pads:
        px_, py_ = fx * w, fy * h
        rx, ry = pw * w * 0.5, ph * h * 0.5
        pad = []
        for a in np.linspace(0.32, 2 * math.pi - 0.32, 70):
            pad.append((px_ + rx * math.cos(a), py_ + ry * math.sin(a)))
        pad.append((px_, py_))
        fill = lingrad((px_, py_ - ry), (px_, py_ + ry), [(0, 0x3B2D20), (1, 0x221911)])
        cv.poly([pad], fill, 0.96, ss=3, blur=0.4)
        cv.draw(lambda d, T, ss, px_=px_, py_=py_, rx=rx, ry=ry: d.arc([*T(px_ - rx * 0.97, py_ - ry * 0.97),
                                                                       *T(px_ + rx * 0.97, py_ + ry * 0.97)],
                                                                      start=20, end=200, fill=255,
                                                                      width=max(1, int(cv.px(2.4) * ss))),
                0xA88669, (px_ - rx - 4, py_ - ry - 4, px_ + rx + 4, py_ + ry + 4), 0.20, mode="add")
    # цветок
    motifs2.lotus(cv, 660, 0.905 * 2868, 1000, halo=1.0)
    # светлячки
    rnd = random.Random(41)
    sp = [(w * rnd.random(), h * (0.38 + 0.50 * rnd.random()), rnd.uniform(4, 9)) for _ in range(22)]
    cv.sparkles(sp, color=0xF4CBC3, alpha=0.55)
    return cv.to_image(9)


# ── Ранголи (светлый фон) ───────────────────────────────────────────────────

def rangoli(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.vgrad([(0.0, 0xFFF4E2), (0.5, 0xFCE6C8), (1.0, 0xF5D3A6)])
    cv.glow(w * 0.5, h * 0.45, w * 0.9, 0xFFFFFF, 0.35, ry=1.3, mode="over")
    g = 165.0                                    # шаг решётки, дизайнерские пиксели
    S = cv.px(g)
    # вес узора по высоте: у середины (где стих) он слабее
    yy = (np.arange(h, dtype=np.float32) + 0.5) / h
    weight = 1 - 0.62 * np.exp(-((yy - 0.47) / 0.20) ** 2)

    def lattice(d, T, ss):
        lw = max(1, int(cv.px(2.2) * ss))
        cols, rows = int(w / S) + 2, int(h / S) + 2
        for j in range(-1, rows):
            for i in range(-1, cols):
                x, y = i * S + (S / 2 if j % 2 else 0), j * S
                # точка-пулли
                r = cv.px(4.0)
                d.ellipse([*T(x - r, y - r), *T(x + r, y + r)], fill=255)
                # лепестки-«цветок» вокруг точки: четыре дуги-петли
                for a0 in (0, 90, 180, 270):
                    a = math.radians(a0)
                    pts = []
                    for t in np.linspace(0, 1, 26):
                        ang = a - 0.52 + 1.04 * t
                        rad = S * 0.34 * math.sin(math.pi * t) ** 0.8 + S * 0.05
                        pts.append(T(x + rad * math.cos(ang) * 1.0, y + rad * math.sin(ang) * 1.0))
                    d.line(pts, fill=255, width=lw, joint="curve")

    m, x0, y0 = cv.draw_mask(lattice, (0, 0, w, h), ss=2, blur=0.5)
    wt = weight[y0:y0 + m.shape[0], None]
    cv.over(0x9B1B2A, m * wt * 0.48, x0, y0)
    # крупная ранголи внизу и поменьше вверху
    for cx_, cy_, r_, a_, col in ((660, 0.865 * 2868, 560, 0.62, 0x9B1B2A), (660, 0.115 * 2868, 400, 0.58, 0xB5541A)):
        cv2 = cv.copy()
        cv2.a[:] = 0
        motifs2.mandala(cv2, cx_, cy_, r_, color=col, alpha=1.0, lines=3.0, mode="add", detail=1.0)
        lay = np.clip(cv2.a.max(-1), 0, 1)
        cv.over(col, lay * a_)
    cv.glow(w * 0.5, h * 0.865, w * 0.35, 0xFFE3A8, 0.35, ry=0.5, mode="over")
    return cv.to_image(10)


# ── Мандала (тёмный фон) ────────────────────────────────────────────────────

def mandala_scene(w=1320):
    cv = _canvas(w)
    h = cv.h
    cv.rgrad(w * 0.5, h * 0.40, 1.2 * w, [(0.0, 0x5A0E14), (0.50, 0x3B090E), (1.0, 0x1C0407)], ry=1.7)
    cv.gauss_glow(w * 0.5, h * 0.40, w * 0.30, 0xF5A04A, 0.16, ry=1.0)
    yy = (np.arange(h, dtype=np.float32) + 0.5) / h
    weight = 1 - 0.60 * np.exp(-((yy - 0.47) / 0.17) ** 2)
    for cx_, cy_, r_, a_ in ((660, 0.385 * 2868, 980, 0.50), (660, 0.935 * 2868, 470, 0.50)):
        cv2 = cv.copy()
        cv2.a[:] = 0
        motifs2.mandala(cv2, cx_, cy_, r_, color=0xF2C45E, alpha=1.0, lines=3.2, mode="add")
        lay = np.clip(cv2.a.max(-1), 0, 1) * weight[:, None]
        cv.add(0xF2C45E, lay * a_)
    cv.sparkles([(w * 0.18, h * 0.12, 9), (w * 0.82, h * 0.20, 11), (w * 0.12, h * 0.78, 8), (w * 0.86, h * 0.70, 10)],
                alpha=0.7)
    return cv.to_image(11)


SCENES = {
    "himalaya": himalaya,
    "ganga": ganga,
    "temple": temple,
    "diya": diya_scene,
    "lotus": lotus_scene,
    "rangoli": rangoli,
    "mandala": mandala_scene,
}
