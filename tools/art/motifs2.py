# -*- coding: utf-8 -*-
"""Мотивы Deepam, часть вторая: лотос, мандала, храм (гопурам). Те же правила, что у `motifs.py`: размеры и
положения — в дизайнерских пикселях кадра, рисуется на `hart.Canvas`."""
import math

import numpy as np

from hart import Canvas, circle, ellipse, lingrad, mix, petal, radgrad, ramp, rgb
from motifs import PLUM_0, PLUM_1, PLUM_2, PLUM_3, MAUVE, ROSE, EMBER, SAFFRON, GOLD, CREAM

# ── лотос ───────────────────────────────────────────────────────────────────

LOTUS_PINK = dict(
    back=(0x5A1850, 0xB5367D),
    mid=(0x96306F, 0xEC74A9),
    front=(0xD35A95, 0xFFC6DD),
)
LOTUS_GOLD = dict(
    back=(0x8A4A10, 0xE9A63A),
    mid=(0xB8701C, 0xFFCB66),
    front=(0xE49A30, 0xFFEBB0),
)


def lotus(cv: Canvas, cx, base_y, size, palette=None, halo=1.0, halo_color=0xFF5E9A, water=True):
    """Цветок лотоса: три ряда узких лепестков веером из одной точки, свечение и кольца на воде.
    `size` — ширина цветка, `base_y` — точка, из которой растут лепестки (дизайнерские пиксели)."""
    pal = palette or LOTUS_PINK
    cx, by, s = cv.px(cx), cv.px(base_y), cv.px(size)
    L = 0.60 * s
    if halo > 0:
        cv.gauss_glow(cx, by - 0.45 * L, 0.70 * L, halo_color, 0.34 * halo)
        cv.gauss_glow(cx, by - 0.20 * L, 1.6 * L, halo_color, 0.10 * halo, ry=0.7)
    if water:
        for k, (rx_, a_) in enumerate(((0.62, 0.30), (0.88, 0.20), (1.15, 0.12))):
            cv.draw(lambda d, T, ss, rx_=rx_: d.ellipse([*T(cx - rx_ * L, by - 0.045 * L * rx_ * 1.3),
                                                        *T(cx + rx_ * L, by + 0.075 * L * rx_ * 1.3)],
                                                       outline=255, width=max(1, int(cv.px(2.2) * ss))),
                    halo_color, (cx - 1.3 * L, by - 0.2 * L, cx + 1.3 * L, by + 0.3 * L), a_, mode="add")

    rows = [
        ("back", [-84, -66, -48, -30, -12, 12, 30, 48, 66, 84], [0.56, 0.70, 0.84, 0.95, 1.0, 1.0, 0.95, 0.84, 0.70, 0.56], 0.98),
        ("mid", [-72, -52, -32, -11, 11, 32, 52, 72], [0.62, 0.80, 0.94, 1.0, 1.0, 0.94, 0.80, 0.62], 0.90),
        ("front", [-54, -30, -8, 8, 30, 54], [0.56, 0.78, 0.90, 0.90, 0.78, 0.56], 0.80),
    ]
    for name, angles, lens, scale in rows:
        c_base, c_tip = pal[name]
        edge = mix(c_base, 0x000000, 0.25)
        order = sorted(range(len(angles)), key=lambda i: -abs(angles[i]))
        for i in order:
            a = math.radians(angles[i])
            Lk = L * lens[i] * scale
            tx, ty = cx + Lk * math.sin(a), by - Lk * math.cos(a)
            wid = 0.44 * Lk
            outer = petal(cx, by, tx, ty, wid, belly=0.40, tip=1.1)
            cv.poly([outer], edge, 1.0, ss=3, blur=0.3)
            ix, iy = cx + (tx - cx) * 0.975, by + (ty - by) * 0.975
            inner = petal(cx, by, ix, iy, wid * 0.90, belly=0.40, tip=1.1)
            fill = lingrad((cx, by), (tx, ty), [(0.0, c_base), (0.5, mix(c_base, c_tip, 0.5)), (1.0, c_tip)])
            cv.poly([inner], fill, 1.0, ss=3, blur=0.3)
            vein = petal(cx + (tx - cx) * 0.12, by + (ty - by) * 0.12, cx + (tx - cx) * 0.84, by + (ty - by) * 0.84,
                         wid * 0.22, belly=0.5)
            cv.poly([vein], c_tip, 0.20, ss=3, blur=cv.px(1.6), mode="add")
    # свет в сердцевине
    cv.gauss_glow(cx, by - 0.10 * L, 0.20 * L, 0xFFD98A, 0.55)
    return cv


# ── мандала ─────────────────────────────────────────────────────────────────

def mandala(cv: Canvas, cx, cy, radius, color=0xE8B64A, alpha=0.55, lines=2.4, mode="add", rot=0.0, detail=1.0):
    """Многослойная мандала из лепестков, колец и бусин. `radius` — внешний радиус в дизайнерских пикселях,
    `lines` — толщина линии, `rot` — поворот в градусах."""
    c_x, c_y, R = cv.px(cx), cv.px(cy), cv.px(radius)
    w = max(1.0, cv.px(lines))
    box = (c_x - R * 1.06, c_y - R * 1.06, c_x + R * 1.06, c_y + R * 1.06)
    rr = math.radians(rot)

    def fn(d, T, ss):
        lw = max(1, int(w * ss))

        def P(r, ang):
            a = ang + rr
            return T(c_x + r * math.cos(a), c_y + r * math.sin(a))

        def ring(r, width=1.0):
            d.ellipse([*T(c_x - r, c_y - r), *T(c_x + r, c_y + r)], outline=255, width=max(1, int(lw * width)))

        def petals(n, r0, r1, wf, off=0.0, width=1.0):
            for k in range(n):
                a = 2 * math.pi * k / n + off
                pts = []
                steps = 24
                for sgn in (1, -1):
                    seq = range(steps + 1) if sgn == 1 else range(steps, -1, -1)
                    for j in seq:
                        t = j / steps
                        rad = r0 + (r1 - r0) * t
                        half = (math.pi / n) * wf * math.sin(math.pi * t) ** 0.9
                        pts.append(P(rad, a + sgn * half * (1 - 0.35 * t)))
                d.line(pts + [pts[0]], fill=255, width=max(1, int(lw * width)), joint="curve")

        def dots(n, r, dr, off=0.0):
            for k in range(n):
                a = 2 * math.pi * k / n + off
                x, y = P(r, a)
                d.ellipse([x - dr * ss, y - dr * ss, x + dr * ss, y + dr * ss], fill=255)

        def teeth(n, r0, r1, off=0.0):
            for k in range(n):
                a = 2 * math.pi * k / n + off
                half = math.pi / n * 0.8
                d.polygon([P(r0, a - half), P(r1, a), P(r0, a + half)], outline=255, width=lw)

        def spokes(n, r0, r1, off=0.0):
            for k in range(n):
                a = 2 * math.pi * k / n + off
                d.line([P(r0, a), P(r1, a)], fill=255, width=max(1, lw // 2))

        d.ellipse([*T(c_x - 0.035 * R, c_y - 0.035 * R), *T(c_x + 0.035 * R, c_y + 0.035 * R)], fill=255)
        ring(0.058 * R)
        petals(8, 0.07 * R, 0.21 * R, 0.78, 0.0)
        petals(8, 0.07 * R, 0.155 * R, 0.62, math.pi / 8)
        ring(0.225 * R)
        dots(24, 0.255 * R, 0.0085 * R)
        ring(0.285 * R, 0.8)
        petals(16, 0.29 * R, 0.475 * R, 0.80, 0.0)
        petals(16, 0.29 * R, 0.40 * R, 0.55, math.pi / 16, 0.8)
        ring(0.49 * R)
        ring(0.51 * R, 0.7)
        teeth(32, 0.515 * R, 0.575 * R, 0.0)
        ring(0.59 * R, 0.8)
        petals(24, 0.60 * R, 0.80 * R, 0.78, math.pi / 24)
        dots(24, 0.70 * R, 0.0075 * R, 0.0)
        ring(0.815 * R)
        dots(48, 0.855 * R, 0.006 * R, 0.0)
        if detail >= 1.0:
            petals(32, 0.875 * R, 0.985 * R, 0.62, 0.0, 0.8)
            ring(R)
            spokes(64, 0.99 * R, 1.04 * R)

    cv.draw(fn, color, box, alpha, ss=2, blur=0.45, mode=mode)
    return cv


# ── храм ────────────────────────────────────────────────────────────────────

def _arch(cx, y_bot, hw, h, n=10):
    """Окно с полукруглым верхом: низ в y_bot, полуширина hw, полная высота h."""
    pts = [(cx - hw, y_bot), (cx + hw, y_bot), (cx + hw, y_bot - (h - hw))]
    for k in range(1, n):
        a = math.pi * k / n
        pts.append((cx + hw * math.cos(a), y_bot - (h - hw) - hw * math.sin(a)))
    pts.append((cx - hw, y_bot - (h - hw)))
    return pts


def gopuram(cv: Canvas, cx, base_y, width, height, color=0x0E0914, tiers=8, windows=0xFFB24A, win_alpha=0.85,
            finials=5, portal=True):
    """Силуэт храмовой башни (гопурам): ярусы с карнизами и нишами, вогнутый к верху профиль, бочкообразная крыша
    и ряд калаш. Размеры — в дизайнерских пикселях; возвращает высоту самой верхней точки в пикселях кадра."""
    cx, by, W, H = cv.px(cx), cv.px(base_y), cv.px(width), cv.px(height)
    polys, lit = [], []
    portal_h = 0.17 * H if portal else 0.0
    roof_h = 0.15 * H
    body_h = H - roof_h - portal_h

    def hw(t):
        return 0.5 * W * (1 - 0.82 * t ** 1.18)

    # портал внизу: широкий короб с высокой аркой входа
    y = by
    if portal:
        pw = 0.5 * W * 0.98
        polys.append([(cx - pw, y), (cx + pw, y), (cx + pw * 0.96, y - portal_h), (cx - pw * 0.96, y - portal_h)])
        lit.append(_arch(cx, y, 0.13 * W, 0.78 * portal_h))
        for sgn in (-1, 1):
            lit.append(_arch(cx + sgn * 0.33 * W, y - 0.22 * portal_h, 0.035 * W, 0.40 * portal_h))
        y -= portal_h
    weights = [1.0 - 0.06 * i for i in range(tiers)]
    total = sum(weights)
    t0 = 0.0
    for i in range(tiers):
        th = body_h * weights[i] / total
        t1 = t0 + weights[i] / total
        hb, ht = hw(t0), hw(t1)
        polys.append([(cx - hb, y), (cx + hb, y), (cx + ht, y - th * 0.80), (cx - ht, y - th * 0.80)])
        cor = ht + 0.026 * W * (1 - 0.5 * t0)
        polys.append([(cx - cor, y - th * 0.80), (cx + cor, y - th * 0.80), (cx + cor - 0.007 * W, y - th),
                      (cx - cor + 0.007 * W, y - th)])
        # ниши-«куду» яруса
        n = max(2, 7 - i)
        for k in range(n):
            tt = (k + 0.5) / n - 0.5
            xx = cx + tt * (hb + ht) * 0.88
            ww = 0.5 * (hb + ht) / n * 0.38
            lit.append(_arch(xx, y - th * 0.14, ww, th * 0.50, 8))
        y -= th
        t0 = t1
    # бочкообразная крыша
    hr = hw(1.0) + 0.03 * W
    roof = [(cx + hr * math.cos(a), y - roof_h * 0.62 * math.sin(a)) for a in np.linspace(0, math.pi, 28)]
    polys.append(roof)
    polys.append([(cx - hr, y), (cx + hr, y), (cx + hr * 0.92, y + 0.012 * W), (cx - hr * 0.92, y + 0.012 * W)])
    top_y = y - roof_h * 0.62
    for k in range(finials):
        t = (k - (finials - 1) / 2) / max(1, (finials - 1) / 2)
        fx = cx + t * hr * 0.80
        fh = roof_h * (0.60 if k % 2 == 0 else 0.46) * (1.0 - 0.16 * abs(t))
        fy0 = y - roof_h * 0.62 * math.sqrt(max(0.0, 1 - (t * 0.80) ** 2)) + 0.004 * W
        r = 0.0095 * W
        polys.append([(fx - r, fy0), (fx + r, fy0), (fx + r * 0.4, fy0 - fh * 0.72), (fx - r * 0.4, fy0 - fh * 0.72)])
        polys.append(ellipse(fx, fy0 - fh * 0.78, r * 1.25, r * 1.7))
        polys.append([(fx - r * 0.35, fy0 - fh * 0.95), (fx + r * 0.35, fy0 - fh * 0.95), (fx, fy0 - fh * 1.25)])
        top_y = min(top_y, fy0 - fh * 1.25)
    cv.poly(polys, color, 1.0, ss=3)
    if windows is not None:
        cv.poly(lit, windows, win_alpha, ss=3, blur=0.5)
        cv.poly(lit, windows, 0.30 * win_alpha, ss=2, blur=cv.px(6), mode="add")
    return top_y
