# -*- coding: utf-8 -*-
"""Приёмы рисования для графики Deepam: фоны, иконки, арт онбординга.

Всё рисуется кодом — без нейросетей и без чужих картинок: так результат воспроизводится из
исходников, чётко на любом размере, а в кадре нет ни людей, ни божеств, ни животных (только
светильник, лотос, мандала, горы, река, храм и свет).

Устройство. `Canvas` держит картинку как массив float32 (высота, ширина, 3) в долях единицы и
рисует поверх неё: градиенты, свечение, силуэты, многоугольники с градиентной заливкой.
Многоугольники рисуются с повышенной дискретизацией (`ss`) и усредняются — края без «лесенки».
Перед записью в файл к кадру добавляется шум в один уровень яркости (`to_image`): без него плавные
градиенты в 8 битах и в JPEG ложатся полосами.

Размеры задаются в «дизайнерских пикселях» кадра шириной 1320 и умножаются на `Canvas.u`, поэтому
одна и та же сцена одинаково собирается в любом масштабе — быстрый предпросмотр и полный размер.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter


# ── цвет ────────────────────────────────────────────────────────────────────

def rgb(h):
    """0xRRGGBB -> массив из трёх долей единицы. Готовый массив возвращается как есть."""
    if not isinstance(h, (int, np.integer)):
        return np.asarray(h, np.float32)
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], np.float32) / 255.0


def mix(a, b, t):
    """Смесь двух цветов (hex или массивы); `t` — число или массив той же формы, что и кадр."""
    a = rgb(a) if isinstance(a, int) else np.asarray(a, np.float32)
    b = rgb(b) if isinstance(b, int) else np.asarray(b, np.float32)
    t = np.asarray(t, np.float32)
    if t.ndim:
        t = t[..., None]
    return a * (1 - t) + b * t


def ramp(t, stops):
    """Цвет по позиции в градиенте: stops = [(позиция, hex), …] по возрастанию позиций.
    `t` — число или массив любой формы; результат — та же форма плюс канал цвета."""
    t = np.asarray(t, np.float32)
    pos = np.array([p for p, _ in stops], np.float32)
    cols = np.array([rgb(c) for _, c in stops], np.float32)
    return np.stack([np.interp(t, pos, cols[:, k]) for k in range(3)], -1)


def lingrad(p0, p1, stops):
    """Заливка вдоль отрезка p0→p1 для `Canvas.poly`: функция (X, Y) -> цвета."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    ln = dx * dx + dy * dy or 1.0

    def fn(X, Y):
        t = np.clip(((X - x0) * dx + (Y - y0) * dy) / ln, 0, 1)
        return ramp(t, stops)
    return fn


def radgrad(cx, cy, r, stops):
    """Радиальная заливка для `Canvas.poly`."""
    def fn(X, Y):
        t = np.clip(np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / r, 0, 1)
        return ramp(t, stops)
    return fn


# ── шум ─────────────────────────────────────────────────────────────────────

def fbm(n, seed, base=3, octaves=5, persistence=0.5):
    """Гладкий одномерный шум длиной n со значениями около 0…1 (дробное броуновское движение)."""
    rnd = np.random.default_rng(seed)
    x = np.linspace(0, 1, n, dtype=np.float32)
    out = np.zeros(n, np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        knots = rnd.random(base * 2 ** o + 2).astype(np.float32)
        pos = x * (len(knots) - 1)
        i = np.minimum(pos.astype(int), len(knots) - 2)
        f = pos - i
        f = f * f * (3 - 2 * f)
        out += amp * (knots[i] * (1 - f) + knots[i + 1] * f)
        total += amp
        amp *= persistence
    return out / total


def fbm2(w, h, seed, base=3, octaves=5, persistence=0.5):
    """Двумерный гладкий шум (h, w) со значениями 0…1: сумма октав, каждая — бикубика по сетке."""
    rnd = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = base * 2 ** o + 2, max(2, int(base * 2 ** o * w / h) + 2)
        grid = rnd.random((gh, gw)).astype(np.float32)
        small = Image.fromarray(grid, "F").resize((w, h), Image.BICUBIC)
        out += amp * np.asarray(small, np.float32)
        total += amp
        amp *= persistence
    out /= total
    lo, hi = out.min(), out.max()
    return (out - lo) / (hi - lo + 1e-9)


# ── мазки ───────────────────────────────────────────────────────────────────

def circle(cx, cy, r, n=64):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def ellipse(cx, cy, rx, ry, n=72, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def petal(bx, by, tx, ty, width, belly=0.45, n=28, tip=1.0):
    """Лепесток: остриё в (tx, ty), основание в (bx, by), наибольшая ширина `width` на доле `belly`
    длины от основания. `tip` > 1 заостряет верхушку."""
    dx, dy = tx - bx, ty - by
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    left, right = [], []
    for k in range(n + 1):
        t = k / n
        # профиль ширины: нуль на концах, максимум около belly
        if t < belly:
            w = math.sin(0.5 * math.pi * t / belly) ** 0.9
        else:
            w = math.cos(0.5 * math.pi * (t - belly) / (1 - belly)) ** (1.25 * tip)
        px, py = bx + ux * ln * t, by + uy * ln * t
        left.append((px + nx * width * 0.5 * w, py + ny * width * 0.5 * w))
        right.append((px - nx * width * 0.5 * w, py - ny * width * 0.5 * w))
    return left + right[::-1]


def flame(cx, base_y, height, width, sway=0.0, n=40):
    """Пламя: круглое снизу, вытянутое и чуть склонённое остриё. `sway` — смещение кончика в долях ширины."""
    left, right = [], []
    for k in range(n + 1):
        t = k / n
        hw = 0.5 * width * (math.sin(math.pi * min(1.0, t * 1.0) ** 0.62) ** 1.05) * (1 - t) ** 0.42
        x_c = cx + sway * width * t ** 2.2
        y = base_y - height * t
        left.append((x_c - hw, y))
        right.append((x_c + hw, y))
    return left + right[::-1]


# ── холст ───────────────────────────────────────────────────────────────────

class Canvas:
    """Кадр как массив float32 (h, w, 3). `u` — множитель дизайнерских пикселей (ширина 1320 → 1)."""

    def __init__(self, w, h, fill=0x000000, design=1320.0):
        self.w, self.h = int(w), int(h)
        self.u = self.w / float(design)
        self.a = np.empty((self.h, self.w, 3), np.float32)
        self.a[:] = rgb(fill)

    # размеры и положения ----------------------------------------------------
    def px(self, v):
        return v * self.u

    def fx(self, f):
        return f * self.w

    def fy(self, f):
        return f * self.h

    # заливки ------------------------------------------------------------------
    def vgrad(self, stops):
        """Вертикальный градиент по всему кадру: stops = [(доля высоты, hex), …]."""
        t = (np.arange(self.h, dtype=np.float32) + 0.5) / self.h
        self.a[:] = ramp(t, stops)[:, None, :]
        return self

    def rgrad(self, cx, cy, r, stops, rx=1.0, ry=1.0):
        """Радиальный градиент по всему кадру (центр и радиус в пикселях)."""
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        d = np.sqrt(((xx - cx) / (r * rx)) ** 2 + ((yy - cy) / (r * ry)) ** 2)
        self.a[:] = ramp(np.clip(d, 0, 1), stops)
        return self

    def _box(self, x0, y0, x1, y1):
        return max(0, int(math.floor(x0))), max(0, int(math.floor(y0))), \
            min(self.w, int(math.ceil(x1))), min(self.h, int(math.ceil(y1)))

    def glow(self, cx, cy, r, color, strength=1.0, power=2.0, rx=1.0, ry=1.0, mode="add"):
        """Мягкое пятно света. `add` складывает свет (как огонь), `over` перекрывает (как дымка).
        Радиус — в пикселях; вне радиуса пятно равно нулю, поэтому считается только его квадрат."""
        x0, y0, x1, y1 = self._box(cx - r * rx, cy - r * ry, cx + r * rx + 1, cy + r * ry + 1)
        if x1 <= x0 or y1 <= y0:
            return self
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d = np.sqrt(((xx + 0.5 - cx) / (r * rx)) ** 2 + ((yy + 0.5 - cy) / (r * ry)) ** 2)
        f = np.clip(1 - d, 0, 1) ** power * strength
        col = rgb(color) if isinstance(color, int) else np.asarray(color, np.float32)
        reg = self.a[y0:y1, x0:x1]
        if mode == "add":
            reg += f[..., None] * col
        else:
            f = np.clip(f, 0, 1)[..., None]
            reg[:] = reg * (1 - f) + col * f
        return self

    def gauss_glow(self, cx, cy, sigma, color, strength=1.0, rx=1.0, ry=1.0):
        """То же пятно, но с гауссовым спадом: у него нет края, и оно мягче `glow`."""
        r = sigma * 3.2
        x0, y0, x1, y1 = self._box(cx - r * rx, cy - r * ry, cx + r * rx + 1, cy + r * ry + 1)
        if x1 <= x0 or y1 <= y0:
            return self
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d2 = ((xx + 0.5 - cx) / (sigma * rx)) ** 2 + ((yy + 0.5 - cy) / (sigma * ry)) ** 2
        f = np.exp(-0.5 * d2) * strength
        col = rgb(color) if isinstance(color, int) else np.asarray(color, np.float32)
        self.a[y0:y1, x0:x1] += f[..., None] * col
        return self

    def over(self, color, alpha, x0=0, y0=0):
        """Накладывает цвет (hex, (3,) или массив) с прозрачностью `alpha` (число или массив) на область
        с левым верхним углом (x0, y0)."""
        if isinstance(alpha, (int, float)):
            self.a[:] = self.a * (1 - alpha) + (rgb(color) if isinstance(color, int) else np.asarray(color)) * alpha
            return self
        h, w = alpha.shape
        x1, y1 = min(self.w, x0 + w), min(self.h, y0 + h)
        al = alpha[:y1 - y0, :x1 - x0, None]
        col = rgb(color) if isinstance(color, int) else np.asarray(color, np.float32)
        if col.ndim == 3:
            col = col[:y1 - y0, :x1 - x0]
        reg = self.a[y0:y1, x0:x1]
        reg[:] = reg * (1 - al) + col * al
        return self

    def add(self, color, amount, x0=0, y0=0):
        """Складывает свет по маске `amount` (массив долей)."""
        h, w = amount.shape
        x1, y1 = min(self.w, x0 + w), min(self.h, y0 + h)
        col = rgb(color) if isinstance(color, int) else np.asarray(color, np.float32)
        self.a[y0:y1, x0:x1] += amount[:y1 - y0, :x1 - x0, None] * col
        return self

    # многоугольники ---------------------------------------------------------
    def mask(self, polys, box=None, ss=3, blur=0.0):
        """Маска из многоугольников: (маска float 0…1, x0, y0). `box` — область в пикселях, по умолчанию
        охватывающая прямоугольник с запасом на размытие."""
        if isinstance(polys[0][0], (int, float)):
            polys = [polys]
        if box is None:
            xs = [p[0] for pts in polys for p in pts]
            ys = [p[1] for pts in polys for p in pts]
            pad = 2 + blur * 3.2
            box = (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
        x0, y0, x1, y1 = self._box(*box)
        if x1 <= x0 or y1 <= y0:
            return np.zeros((0, 0), np.float32), x0, y0
        W, H = x1 - x0, y1 - y0
        im = Image.new("L", (W * ss, H * ss), 0)
        d = ImageDraw.Draw(im)
        for pts in polys:
            d.polygon([((x - x0) * ss, (y - y0) * ss) for x, y in pts], fill=255)
        m = np.asarray(im.resize((W, H), Image.BOX), np.float32) / 255.0
        if blur > 0:
            m = gaussian_filter(m, blur)
        return m, x0, y0

    def poly(self, polys, fill, opacity=1.0, ss=3, blur=0.0, mode="over"):
        """Заливает многоугольники. `fill` — hex, массив цвета или функция (X, Y) -> цвета.
        `mode="add"` складывает свет вместо перекрытия."""
        m, x0, y0 = self.mask(polys, ss=ss, blur=blur)
        if m.size == 0:
            return self
        h, w = m.shape
        if callable(fill):
            yy, xx = np.mgrid[y0:y0 + h, x0:x0 + w].astype(np.float32)
            col = fill(xx + 0.5, yy + 0.5)
        else:
            col = rgb(fill) if isinstance(fill, int) else np.asarray(fill, np.float32)
        if mode == "add":
            return self.add(col, m * opacity, x0, y0) if col.ndim == 1 else self._add_arr(col, m * opacity, x0, y0)
        return self.over(col, m * opacity, x0, y0)

    def draw(self, fn, fill, box, opacity=1.0, ss=2, blur=0.0, mode="over"):
        """Рисует линии, дуги и окружности средствами PIL. `fn(d, T, s)`: `d` — `ImageDraw` по маске, `T(x, y)` —
        перевод координат кадра в координаты маски, `s` — во сколько раз маска крупнее кадра (для толщины линий).
        `box` — область кадра, в которую укладывается рисунок."""
        x0, y0, x1, y1 = self._box(*box)
        if x1 <= x0 or y1 <= y0:
            return self
        W, H = x1 - x0, y1 - y0
        im = Image.new("L", (W * ss, H * ss), 0)
        fn(ImageDraw.Draw(im), lambda x, y: ((x - x0) * ss, (y - y0) * ss), ss)
        m = np.asarray(im.resize((W, H), Image.BOX), np.float32) / 255.0
        if blur > 0:
            m = gaussian_filter(m, blur)
        if callable(fill):
            yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
            col = fill(xx + 0.5, yy + 0.5)
        else:
            col = rgb(fill) if isinstance(fill, int) else np.asarray(fill, np.float32)
        if mode == "add":
            return self.add(col, m * opacity, x0, y0) if col.ndim == 1 else self._add_arr(col, m * opacity, x0, y0)
        return self.over(col, m * opacity, x0, y0)

    def draw_mask(self, fn, box, ss=2, blur=0.0):
        """Как `draw`, но возвращает маску (m, x0, y0), а не кладёт её на кадр: её можно умножить на
        свой вес (например, приглушить узор под текстом) и наложить через `over`/`add`."""
        x0, y0, x1, y1 = self._box(*box)
        if x1 <= x0 or y1 <= y0:
            return np.zeros((0, 0), np.float32), x0, y0
        W, H = x1 - x0, y1 - y0
        im = Image.new("L", (W * ss, H * ss), 0)
        fn(ImageDraw.Draw(im), lambda x, y: ((x - x0) * ss, (y - y0) * ss), ss)
        m = np.asarray(im.resize((W, H), Image.BOX), np.float32) / 255.0
        if blur > 0:
            m = gaussian_filter(m, blur)
        return m, x0, y0

    def _add_arr(self, col, amount, x0, y0):
        h, w = amount.shape
        x1, y1 = min(self.w, x0 + w), min(self.h, y0 + h)
        self.a[y0:y1, x0:x1] += (col * amount[..., None])[:y1 - y0, :x1 - x0]
        return self

    def ridge(self, ys, fill, opacity=1.0):
        """Силуэт ниже линии `ys` (по одному значению на столбец): горы, берег, горизонт. Край сглажен по
        вертикали аналитически. `fill` — цвет или функция (X, Y) -> цвета."""
        yy = np.arange(self.h, dtype=np.float32)[:, None] + 0.5
        alpha = np.clip(yy - ys[None, :] + 0.5, 0, 1)
        if callable(fill):
            Y, X = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
            col = fill(X + 0.5, Y + 0.5)
        else:
            col = rgb(fill) if isinstance(fill, int) else np.asarray(fill, np.float32)
        al = (alpha * opacity)[..., None]
        self.a[:] = self.a * (1 - al) + col * al
        return self

    # звёзды ---------------------------------------------------------------------
    def stars(self, n, y_max, seed, sizes=(0.7, 1.7), alpha=(0.25, 0.95), tint=0xFFF1DC, bias=1.6, big=0):
        """Звёзды: `n` точек выше `y_max` (доля высоты), плотнее к верху (`bias`). `big` самых крупных получают
        четырёхлучевой блик."""
        rnd = random.Random(seed)
        col = rgb(tint)
        for i in range(n):
            x = rnd.random() * self.w
            y = (rnd.random() ** bias) * y_max * self.h
            r = self.px(rnd.uniform(*sizes))
            a = rnd.uniform(*alpha)
            self.gauss_glow(x, y, max(0.55, r * 0.55), col, a, )
            if i < big:
                self.gauss_glow(x, y, r * 2.4, col, a * 0.35)
                L = r * 9
                for ang in (0, math.pi / 2):
                    dx, dy = math.cos(ang), math.sin(ang)
                    steps = int(L * 2)
                    # луч: ряд маленьких гауссовых пятен, убывающих от центра
                    for k in range(-steps, steps + 1, 2):
                        f = (1 - abs(k) / steps) ** 2.4
                        self.gauss_glow(x + dx * k * 0.5, y + dy * k * 0.5, max(0.5, r * 0.3), col, a * 0.5 * f)
        return self

    def sparkles(self, pts, color=0xFFE8B0, scale=1.0, alpha=0.9):
        """Четырёхконечные блики в заданных точках: (x, y, радиус в дизайнерских пикселях)."""
        for x, y, r in pts:
            r = self.px(r) * scale
            poly = []
            for k in range(8):
                rr = r if k % 2 == 0 else r * 0.16
                a = math.pi / 4 * k - math.pi / 2
                poly.append((x + rr * math.cos(a), y + rr * math.sin(a)))
            self.poly(poly, color, alpha * 0.9, ss=4, blur=0.5, mode="add")
            self.gauss_glow(x, y, r * 0.45, color, alpha * 0.55)
        return self

    # вывод ------------------------------------------------------------------------
    def to_image(self, seed=0, dither=True):
        arr = np.clip(self.a, 0, 1) * 255.0
        if dither:
            rnd = np.random.default_rng(seed)
            noise = (rnd.random(arr.shape[:2], dtype=np.float32) + rnd.random(arr.shape[:2], dtype=np.float32) - 1.0)
            arr = arr + noise[..., None] * 0.9
        return Image.fromarray(np.clip(np.rint(arr), 0, 255).astype(np.uint8), "RGB")

    def copy(self):
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c


def font(path, size):
    return ImageFont.truetype(path, int(size))
