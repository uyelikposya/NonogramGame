#!/usr/bin/env python3
"""Kedi türü bölümlerini üretir (yalnızca Python 3 standart kütüphanesi).

Kullanım:  python3 Tools/generate_content.py

Her tür için `BREEDS` içindeki özelliklerden (kulak şekli, desen, göz rengi, palet,
türe özgü sahneler) vektör çizimler oluşturulur, hedef ızgara boyutunda piksele
dönüştürülür ve yalnızca **tahmin yapmadan çözülebilen** bulmacalar tutulur.
Çıktı deterministiktir: aynı kod her zaman aynı JSON'ları üretir.

Yeni tür eklemek:  BREEDS listesine bir giriş eklemek ve scripti çalıştırmak yeterli.
Elle çizilmiş bulmacalar (`HANDMADE`) her türün başına eklenir.
"""
import json
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_puzzles import clue, solve_logically  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PUZZLES = ROOT / "Catgrid/Resources/Puzzles"
PUZZLES_PER_BREED = 15


# MARK: - Çizim primitifleri (0...1 normalize koordinatlar, y aşağı doğru)

class Shape:
    def __init__(self, role, weight=1.0):
        self.role = role
        self.weight = weight


class Ellipse(Shape):
    def __init__(self, cx, cy, rx, ry, role, weight=1.0):
        super().__init__(role, weight)
        self.cx, self.cy, self.rx, self.ry = cx, cy, rx, ry

    def contains(self, x, y):
        return ((x - self.cx) / self.rx) ** 2 + ((y - self.cy) / self.ry) ** 2 <= 1


class Poly(Shape):
    def __init__(self, points, role, weight=1.0):
        super().__init__(role, weight)
        self.points = points

    def contains(self, x, y):
        inside = False
        pts = self.points
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                inside = not inside
            j = i
        return inside


class Line(Shape):
    """Kalınlığı `width` olan yuvarlak uçlu çizgi (birden çok noktadan geçebilir)."""

    def __init__(self, points, width, role, weight=1.0):
        super().__init__(role, weight)
        self.points, self.width = points, width

    def contains(self, x, y):
        for (x1, y1), (x2, y2) in zip(self.points, self.points[1:]):
            dx, dy = x2 - x1, y2 - y1
            t = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy or 1)))
            if math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)) <= self.width / 2:
                return True
        return False


class Rect(Shape):
    def __init__(self, x0, y0, x1, y1, role, weight=1.0):
        super().__init__(role, weight)
        self.box = (x0, y0, x1, y1)

    def contains(self, x, y):
        x0, y0, x1, y1 = self.box
        return x0 <= x <= x1 and y0 <= y <= y1


CUT = "."  # boşluk açan şekil rolü (göz bebeği, yün çizgileri...)
FEATURE = 2.2  # küçük ayrıntıların (göz, burun) çoğunluk oylamasında kaybolmaması için ağırlık


def bounds(shapes, resolution=96):
    """Çizimin kapladığı alan (boşluk açan şekiller hariç)."""
    solid = [s for s in shapes if s.role != CUT]
    xs, ys = [], []
    for i in range(resolution):
        for j in range(resolution):
            x = -0.1 + 1.2 * (j + 0.5) / resolution
            y = -0.1 + 1.2 * (i + 0.5) / resolution
            if any(s.contains(x, y) for s in solid):
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)


def canvas_size(box, n):
    """Uzun kenar n kare; kısa kenar orana göre (dikdörtgen bulmacalar serbest)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if w >= h:
        return max(4, round(n * h / w)), n
    return n, max(4, round(n * w / h))


def rasterize(shapes, box, rows, cols, mirror=False, scale=1.0, dx=0.0, dy=0.0, samples=4):
    """Çizimi sınırlayıcı kutusuna oturtup rows x cols ızgaraya çevirir.
    scale/dx/dy küçük oynamalar üretir (aynı motiften farklı bulmacalar)."""
    x0, y0, x1, y1 = box
    w, h = (x1 - x0) / scale, (y1 - y0) / scale
    cx, cy = (x0 + x1) / 2 + dx * w, (y0 + y1) / 2 + dy * h
    grid = []
    for r in range(rows):
        row = []
        for c in range(cols):
            votes = {}
            empty = 0
            for i in range(samples):
                for j in range(samples):
                    u = (c + (j + 0.5) / samples) / cols - 0.5
                    v = (r + (i + 0.5) / samples) / rows - 0.5
                    x = cx + (-u if mirror else u) * w
                    y = cy + v * h
                    hit = None
                    for shape in shapes:
                        if shape.contains(x, y):
                            hit = shape
                    if hit is None:
                        empty += 1
                    else:
                        votes[hit.role] = votes.get(hit.role, 0) + hit.weight
            total = samples * samples
            if total - empty < total * 0.5 or not votes:
                row.append(".")
                continue
            role = max(votes, key=votes.get)
            row.append("." if role == CUT else role)
        grid.append("".join(row))
    return grid


# MARK: - Kulak ve desen yardımcıları

def ears(t, head_top, spread=0.22, role="b"):
    """İki kulak; şekli türün `ears` özelliğinden gelir. Desen rengi (points) kulakları boyar."""
    kind = t["ears"]
    color = "d" if "points" in t["pattern"] or "van" in t["pattern"] else role
    shapes = []
    for side in (-1, 1):
        base_out = 0.5 + side * (spread + 0.14)
        base_in = 0.5 + side * (spread - 0.08)
        if kind == "folded":
            tip = (0.5 + side * (spread + 0.06), head_top + 0.02)
            shapes.append(Poly([(base_out, head_top + 0.12), tip, (base_in, head_top + 0.06)], color))
        else:
            height = {"large": 0.26, "small": 0.13, "tufted": 0.22}.get(kind, 0.19)
            width = 0.05 if kind == "large" else 0.0
            tip = (0.5 + side * (spread + 0.08 + width), head_top - height)
            shapes.append(Poly([(base_out + side * width, head_top + 0.1), tip, (base_in, head_top + 0.06)], color))
            if kind == "tufted":
                shapes.append(Line([tip, (tip[0] + side * 0.01, tip[1] - 0.045)], 0.03, "d"))
    return shapes


def coat(t, region, density=1.0):
    """Gövde/baş üzerine türün desenini (çizgi, benek, rozet) çizer. region=(cx, cy, rx, ry)."""
    cx, cy, rx, ry = region
    pattern = t["pattern"]
    shapes = []
    if "tabby" in pattern:
        for k in (-1, 0, 1):
            x = cx + k * rx * 0.35
            shapes.append(Line([(x, cy - ry * 0.75), (x, cy - ry * 0.25)], 0.045, "d"))
    if "spots" in pattern:
        rng = random.Random(f"{t['id']}-{region}")
        for _ in range(int(7 * density)):
            a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0.15, 0.75)
            shapes.append(Ellipse(cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d, 0.045, 0.04, "d"))
    if "patches" in pattern:
        shapes.append(Ellipse(cx - rx * 0.45, cy - ry * 0.35, rx * 0.4, ry * 0.32, "d"))
        shapes.append(Ellipse(cx + rx * 0.4, cy + ry * 0.2, rx * 0.35, ry * 0.3, "k"))
    if "ticked" in pattern:
        shapes.append(Ellipse(cx, cy - ry * 0.55, rx * 0.35, ry * 0.25, "d"))
    return shapes


def tail(t, points, width, role):
    """Türün kuyruğu: Manx'te hiç yok, Japon Bobtail'de kısa bir ponpon."""
    kind = t.get("tail", "long")
    if kind == "none":
        return []
    if kind == "bob":
        (x0, y0), (x1, y1) = points[0], points[1]
        return [Ellipse(x0 + (x1 - x0) * 0.3, y0 + (y1 - y0) * 0.3, width * 0.9, width * 0.9, role)]
    return [Line(points, width, role)]


def tail_role(t):
    return "d" if any(p in t["pattern"] for p in ("points", "van", "tabby", "patches")) else "b"


def eyes(t, y, gap, size, slit=True):
    # Dikey göz bebeği yalnızca büyük ızgaralarda okunaklı; küçüklerde göz tek renk kalır
    slit = slit and t.get("size", 20) >= 15
    shapes = []
    for side, role in ((-1, "e"), (1, "f" if t.get("odd_eyes") else "e")):
        x = 0.5 + side * gap
        shapes.append(Ellipse(x, y, size, size * 1.1, role, FEATURE))
        if slit:
            shapes.append(Line([(x, y - size * 0.6), (x, y + size * 0.6)], size * 0.55, CUT, FEATURE))
    return shapes


# MARK: - Motifler: t (tür özellikleri) alır, şekil listesi döner

def portrait(t):
    w = t.get("head_w", 0.36)
    head = (0.5, 0.58, w, 0.32)
    shapes = ears(t, 0.36, spread=w * 0.62)
    shapes.append(Ellipse(*head, "b"))
    if t.get("fluffy"):
        shapes += [Ellipse(0.5 + s * (w + 0.02), 0.7, 0.07, 0.1, "b") for s in (-1, 1)]
    if "van" in t["pattern"]:
        shapes += [Ellipse(0.5 + s * w * 0.55, 0.38, w * 0.42, 0.13, "d") for s in (-1, 1)]
    if "points" in t["pattern"]:
        shapes.append(Ellipse(0.5, 0.66, w * 0.55, 0.2, "d"))
    if "bib" in t["pattern"] or "mitts" in t["pattern"]:
        shapes.append(Ellipse(0.5, 0.78, w * 0.5, 0.12, "w"))
    shapes += coat(t, head, 0.6)
    shapes += eyes(t, 0.56, w * 0.42, 0.065)
    shapes.append(Poly([(0.46, 0.68), (0.54, 0.68), (0.5, 0.73)], "n", FEATURE))
    return shapes


def sitting(t):
    shapes = [Ellipse(0.52, 0.7, 0.24, 0.25, "b")]
    shapes += [Ellipse(0.42, 0.33, 0.17, 0.15, "b")]
    shapes += [_shift(s, -0.08) for s in ears(t, 0.24, spread=0.09)]
    tail_w = 0.13 if t.get("fluffy") else 0.08
    shapes += tail(t, [(0.74, 0.9), (0.9, 0.78), (0.88, 0.52)], tail_w, tail_role(t))
    paw_role = "w" if "mitts" in t["pattern"] else ("d" if "points" in t["pattern"] else "b")
    shapes += [Ellipse(x, 0.93, 0.07, 0.05, paw_role) for x in (0.38, 0.55)]
    shapes += coat(t, (0.55, 0.7, 0.2, 0.22))
    if "points" in t["pattern"]:
        shapes.append(Ellipse(0.4, 0.38, 0.09, 0.07, "d"))
    return shapes


def sleeping(t):
    shapes = [Ellipse(0.55, 0.64, 0.38, 0.24, "b"), Ellipse(0.26, 0.6, 0.17, 0.16, "b")]
    shapes += [_shift(s, -0.24, 0.02) for s in ears(t, 0.5, spread=0.08)]
    shapes += tail(t, [(0.9, 0.7), (0.75, 0.88), (0.3, 0.86)], 0.12 if t.get("fluffy") else 0.08, tail_role(t))
    shapes += [Line([(x - 0.04, 0.6), (x + 0.04, 0.6)], 0.035, CUT, FEATURE) for x in (0.2, 0.32)]
    shapes += coat(t, (0.58, 0.62, 0.3, 0.2))
    return shapes


def paw(t):
    base = "w" if "mitts" in t["pattern"] else "b"
    shapes = [Ellipse(0.5, 0.64, 0.3, 0.26, base)]
    shapes += [Ellipse(x, y, 0.1, 0.12, base) for x, y in ((0.2, 0.36), (0.38, 0.2), (0.62, 0.2), (0.8, 0.36))]
    shapes.append(Ellipse(0.5, 0.68, 0.16, 0.13, "n", FEATURE))
    shapes += [Ellipse(x, y, 0.05, 0.06, "n", FEATURE) for x, y in ((0.2, 0.37), (0.38, 0.21), (0.62, 0.21), (0.8, 0.37))]
    return shapes


def yarn(t):
    shapes = [Ellipse(0.46, 0.46, 0.36, 0.36, "o")]
    shapes += [Line([(0.2, 0.3), (0.5, 0.42), (0.74, 0.66)], 0.05, CUT, FEATURE),
               Line([(0.28, 0.66), (0.6, 0.24)], 0.05, CUT, FEATURE)]
    shapes.append(Line([(0.72, 0.76), (0.86, 0.9), (0.96, 0.84)], 0.06, "o"))
    return shapes


def fish(t):
    return [Ellipse(0.42, 0.5, 0.32, 0.22, "o"),
            Poly([(0.68, 0.5), (0.96, 0.26), (0.96, 0.74)], "o"),
            Ellipse(0.24, 0.45, 0.05, 0.05, CUT, FEATURE),
            Line([(0.46, 0.34), (0.46, 0.66)], 0.04, "p", FEATURE)]


def fishbone(t):
    shapes = [Line([(0.18, 0.5), (0.84, 0.5)], 0.07, "p"),
              Poly([(0.04, 0.5), (0.24, 0.32), (0.24, 0.68)], "p"),
              Poly([(0.8, 0.5), (0.97, 0.3), (0.97, 0.7)], "p")]
    shapes += [Line([(x, 0.3), (x, 0.7)], 0.06, "p") for x in (0.36, 0.5, 0.64)]
    return shapes


def bowl(t):
    return [Poly([(0.08, 0.52), (0.92, 0.52), (0.78, 0.86), (0.22, 0.86)], "o"),
            Ellipse(0.5, 0.48, 0.34, 0.12, "p"),
            Ellipse(0.38, 0.4, 0.07, 0.06, "p"), Ellipse(0.58, 0.38, 0.08, 0.07, "p"),
            Line([(0.3, 0.68), (0.7, 0.68)], 0.06, "w", FEATURE)]


def heart(t):
    return [Ellipse(0.32, 0.36, 0.22, 0.2, "n"), Ellipse(0.68, 0.36, 0.22, 0.2, "n"),
            Poly([(0.1, 0.44), (0.9, 0.44), (0.5, 0.92)], "n"),
            Ellipse(0.3, 0.32, 0.06, 0.05, "w", FEATURE)]


def mouse(t):
    return [Ellipse(0.46, 0.6, 0.28, 0.2, "p"), Poly([(0.18, 0.6), (0.05, 0.62), (0.22, 0.5)], "p"),
            Ellipse(0.36, 0.4, 0.1, 0.1, "p"), Ellipse(0.36, 0.4, 0.05, 0.05, "n", FEATURE),
            Line([(0.72, 0.68), (0.86, 0.82), (0.95, 0.66)], 0.05, "n"),
            Ellipse(0.22, 0.56, 0.035, 0.035, CUT, FEATURE)]


def box(t):
    shapes = [Rect(0.1, 0.5, 0.9, 0.95, "o"), Poly([(0.1, 0.5), (0.0, 0.62), (0.22, 0.62)], "p"),
              Poly([(0.9, 0.5), (1.0, 0.62), (0.78, 0.62)], "p")]
    shapes += [Ellipse(0.5, 0.42, 0.26, 0.2, "b")]
    shapes += [_shift(s, 0, -0.06) for s in ears(t, 0.3, spread=0.14)]
    shapes += eyes(t, 0.42, 0.1, 0.05, slit=False)
    shapes.append(Line([(0.1, 0.72), (0.9, 0.72)], 0.04, CUT))
    return shapes


def moon(t):
    return [Ellipse(0.6, 0.38, 0.32, 0.32, "y"), Ellipse(0.78, 0.28, 0.26, 0.26, CUT),
            Ellipse(0.32, 0.8, 0.12, 0.13, "b"), Ellipse(0.26, 0.62, 0.08, 0.07, "b"),
            Poly([(0.19, 0.6), (0.2, 0.5), (0.25, 0.57)], "b"), Poly([(0.33, 0.6), (0.32, 0.5), (0.27, 0.57)], "b"),
            Line([(0.42, 0.9), (0.56, 0.86), (0.58, 0.72)], 0.05, "b")]


def walking(t):
    shapes = [Ellipse(0.52, 0.52, 0.3, 0.16, "b"), Ellipse(0.2, 0.4, 0.14, 0.13, "b")]
    shapes += [_shift(s, -0.3, 0.0) for s in ears(t, 0.32, spread=0.07)]
    leg = "w" if "mitts" in t["pattern"] else ("d" if "points" in t["pattern"] else "b")
    shapes += [Line([(x, 0.6), (x + dx, 0.9)], 0.07, leg) for x, dx in ((0.3, -0.03), (0.42, 0.03), (0.66, -0.03), (0.76, 0.03))]
    shapes += tail(t, [(0.8, 0.46), (0.94, 0.3), (0.9, 0.12)], 0.12 if t.get("fluffy") else 0.07, tail_role(t))
    shapes += coat(t, (0.55, 0.5, 0.24, 0.13))
    return shapes


# Türe özgü sahneler

def teacup(t):
    return [Poly([(0.12, 0.55), (0.82, 0.55), (0.72, 0.92), (0.22, 0.92)], "o"),
            Line([(0.82, 0.62), (0.95, 0.68), (0.8, 0.82)], 0.06, "o"),
            Ellipse(0.47, 0.5, 0.24, 0.16, "b")] + [_shift(s, -0.03, 0.04) for s in ears(t, 0.34, spread=0.13)] + \
        eyes(t, 0.5, 0.1, 0.045, slit=False) + [Line([(0.18, 0.7), (0.76, 0.7)], 0.05, "p")]


def owl_sit(t):
    return [Ellipse(0.5, 0.68, 0.32, 0.3, "b"), Ellipse(0.5, 0.36, 0.3, 0.24, "b")] + ears(t, 0.18, spread=0.18) + \
        eyes(t, 0.36, 0.13, 0.075) + [Ellipse(0.5, 0.74, 0.16, 0.18, "w")] + coat(t, (0.5, 0.36, 0.3, 0.24))


def cushion(t):
    return [Rect(0.04, 0.68, 0.96, 0.92, "o"), Ellipse(0.5, 0.6, 0.38, 0.2, "b"),
            Ellipse(0.32, 0.42, 0.18, 0.17, "b")] + [_shift(s, -0.18, 0.0) for s in ears(t, 0.3, spread=0.08)] + \
        [Line([(0.04, 0.8), (0.96, 0.8)], 0.035, "p"), Ellipse(0.32, 0.46, 0.05, 0.03, "n", FEATURE)]


def belly_up(t):
    paw = "w" if "mitts" in t["pattern"] else "d"
    return [Ellipse(0.5, 0.6, 0.34, 0.22, "b"), Ellipse(0.5, 0.62, 0.2, 0.13, "w"),
            Ellipse(0.2, 0.5, 0.16, 0.15, "b")] + \
        [Line([(x, 0.42), (x + d, 0.14)], 0.08, "b") for x, d in ((0.4, -0.06), (0.62, 0.06))] + \
        [Ellipse(x + d, 0.13, 0.06, 0.05, paw) for x, d in ((0.4, -0.06), (0.62, 0.06))] + \
        [Line([(0.84, 0.62), (0.96, 0.84)], 0.08, "d")]


def night(t):
    return moon(t) + [Ellipse(0.12, 0.16, 0.04, 0.04, "y"), Ellipse(0.9, 0.86, 0.035, 0.035, "y")]


def bastet(t):
    return [Ellipse(0.5, 0.72, 0.2, 0.24, "b"), Rect(0.38, 0.4, 0.62, 0.72, "b"),
            Ellipse(0.5, 0.28, 0.13, 0.13, "b"),
            Poly([(0.38, 0.24), (0.36, 0.02), (0.48, 0.18)], "b"), Poly([(0.62, 0.24), (0.64, 0.02), (0.52, 0.18)], "b"),
            Line([(0.66, 0.92), (0.82, 0.86), (0.84, 0.62)], 0.06, "d"),
            Rect(0.4, 0.44, 0.6, 0.5, "y"), Ellipse(0.46, 0.27, 0.025, 0.025, CUT, FEATURE)] + \
        [Poly([(0.0, 0.98), (0.2, 0.62), (0.4, 0.98)], "o")]


def gloves(t):
    return [Ellipse(0.3, 0.42, 0.22, 0.32, "b"), Ellipse(0.7, 0.42, 0.22, 0.32, "b"),
            Ellipse(0.3, 0.78, 0.2, 0.16, "w"), Ellipse(0.7, 0.78, 0.2, 0.16, "w")] + \
        [Line([(x, 0.7), (x, 0.88)], 0.035, CUT) for x in (0.24, 0.36, 0.64, 0.76)]


def jungle(t):
    return [Ellipse(0.5, 0.62, 0.36, 0.22, "b"), Ellipse(0.2, 0.42, 0.15, 0.14, "b")] + \
        [_shift(s, -0.3, 0.0) for s in ears(t, 0.34, spread=0.07)] + coat(t, (0.52, 0.6, 0.3, 0.18), 1.6) + \
        [Poly([(0.6, 0.04), (0.96, 0.2), (0.7, 0.36)], "g"), Line([(0.62, 0.06), (0.86, 0.3)], 0.03, CUT)]


def sweater(t):
    return portrait({**t, "pattern": []})[:-1] + [Rect(0.18, 0.82, 0.82, 1.0, "o"),
                                                    Line([(0.18, 0.9), (0.82, 0.9)], 0.04, "p")]


def bow(t):
    return portrait(t) + [Poly([(0.5, 0.86), (0.3, 0.76), (0.3, 0.98)], "n"),
                          Poly([(0.5, 0.86), (0.7, 0.76), (0.7, 0.98)], "n"), Ellipse(0.5, 0.87, 0.05, 0.05, "o")]


def forest(t):
    return [Poly([(0.78, 0.02), (0.98, 0.5), (0.58, 0.5)], "g"), Poly([(0.78, 0.3), (1.0, 0.82), (0.56, 0.82)], "g"),
            Rect(0.74, 0.82, 0.82, 0.96, "o")] + [_shift(_scale(s, 0.8), -0.12, 0.08) for s in sitting(t)]


def swimming(t):
    return [_shift(s, 0, -0.1) for s in portrait(t)] + \
        [Line([(0.0, 0.84), (0.16, 0.76), (0.33, 0.84), (0.5, 0.76), (0.67, 0.84), (0.84, 0.76), (1.0, 0.84)], 0.09, "u"),
         Rect(0.0, 0.9, 1.0, 1.0, "u")]


def big_tail(t):
    return [Ellipse(0.4, 0.66, 0.24, 0.24, "b"), Ellipse(0.3, 0.32, 0.17, 0.15, "b")] + \
        [_shift(s, -0.2, 0) for s in ears(t, 0.22, spread=0.09)] + \
        [Line([(0.6, 0.86), (0.86, 0.72), (0.88, 0.4), (0.74, 0.2)], 0.18, "d"),
         Line([(0.62, 0.86), (0.84, 0.72), (0.86, 0.42)], 0.05, "b")] + coat(t, (0.42, 0.66, 0.2, 0.2))


def lucky(t):
    """Maneki-neko: kalkık patili şans kedisi, boynunda çan, önünde altın para."""
    shapes = [Ellipse(0.5, 0.72, 0.26, 0.24, "b"), Ellipse(0.5, 0.38, 0.24, 0.2, "b")]
    shapes += ears(t, 0.24, spread=0.13)
    shapes += coat(t, (0.5, 0.38, 0.24, 0.2), 0.6)
    shapes += [Line([(0.7, 0.62), (0.82, 0.36), (0.82, 0.18)], 0.1, "b"), Ellipse(0.82, 0.16, 0.07, 0.06, "b")]
    shapes += eyes(t, 0.38, 0.09, 0.045, slit=False)
    shapes += [Line([(0.32, 0.55), (0.68, 0.55)], 0.04, "n"), Ellipse(0.5, 0.59, 0.04, 0.04, "y", FEATURE),
               Ellipse(0.5, 0.78, 0.13, 0.09, "y"), Line([(0.42, 0.78), (0.58, 0.78)], 0.03, "o", FEATURE)]
    return shapes


def teddy(t):
    return portrait({**t, "head_w": 0.42}) + [Ellipse(0.5, 0.74, 0.13, 0.08, "w")]


# Bu boyuttan küçük ızgaralarda okunmayan motifler
MIN_SIZE = dict(lucky=9, portrait=7, sitting=9, sleeping=9, walking=11, box=8, moon=8, teacup=9, owl=8, cushion=9,
                bellyup=10, night=10, bastet=10, gloves=8, jungle=11, sweater=9, bow=10, forest=12,
                swimming=9, bigtail=10, teddy=8)

MOTIFS = {
    "portrait": (portrait, "Portrait", "Portre"),
    "sitting": (sitting, "Sitting Pretty", "Uslu Oturuş"),
    "sleeping": (sleeping, "Nap Time", "Şekerleme"),
    "paw": (paw, "Toe Beans", "Pati Yastıkları"),
    "yarn": (yarn, "Yarn Ball", "Yün Yumak"),
    "fish": (fish, "Fish Snack", "Balık Atıştırması"),
    "fishbone": (fishbone, "Leftovers", "Artıklar"),
    "bowl": (bowl, "Dinner Bowl", "Mama Kabı"),
    "heart": (heart, "Purr Love", "Mırıl Sevgi"),
    "mouse": (mouse, "Toy Mouse", "Oyuncak Fare"),
    "box": (box, "If I Fits", "Kutu Sevdası"),
    "moon": (moon, "Moon Gazer", "Ay Seyri"),
    "walking": (walking, "Strut", "Salınarak Yürüyüş"),
    "teacup": (teacup, "Teacup Cat", "Fincandaki Kedi"),
    "owl": (owl_sit, "Owl Pose", "Baykuş Duruşu"),
    "cushion": (cushion, "Royal Cushion", "Saray Minderi"),
    "bellyup": (belly_up, "Floppy Hug", "Gevşek Kucaklama"),
    "night": (night, "Silver Night", "Gümüş Gece"),
    "bastet": (bastet, "Ancient Grace", "Kadim Zarafet"),
    "gloves": (gloves, "White Gloves", "Beyaz Eldivenler"),
    "jungle": (jungle, "Jungle Prowl", "Orman Avcısı"),
    "sweater": (sweater, "Cozy Sweater", "Sıcak Kazak"),
    "bow": (bow, "Silk Ribbon", "İpek Kurdele"),
    "forest": (forest, "Forest Guardian", "Orman Bekçisi"),
    "swimming": (swimming, "Lake Swimmer", "Göl Yüzücüsü"),
    "bigtail": (big_tail, "Mighty Tail", "Görkemli Kuyruk"),
    "teddy": (teddy, "Teddy Face", "Oyuncak Ayı Yüzü"),
    "lucky": (lucky, "Lucky Cat", "Şans Kedisi"),
}


def _shift(shape, dx=0.0, dy=0.0):
    return _transform(shape, lambda x, y: (x + dx, y + dy))


def _scale(shape, k):
    return _transform(shape, lambda x, y: (0.5 + (x - 0.5) * k, 0.5 + (y - 0.5) * k), k)


def _transform(shape, f, k=1.0):
    if isinstance(shape, Ellipse):
        cx, cy = f(shape.cx, shape.cy)
        return Ellipse(cx, cy, shape.rx * k, shape.ry * k, shape.role, shape.weight)
    if isinstance(shape, Poly):
        return Poly([f(x, y) for x, y in shape.points], shape.role, shape.weight)
    if isinstance(shape, Line):
        return Line([f(x, y) for x, y in shape.points], shape.width * k, shape.role, shape.weight)
    x0, y0, x1, y1 = shape.box
    (a, b), (c, d) = f(x0, y0), f(x1, y1)
    return Rect(a, b, c, d, shape.role, shape.weight)


# MARK: - Türler

COMMON = ["paw", "heart", "fish", "yarn", "bowl", "mouse", "fishbone", "portrait", "sleeping", "sitting",
          "walking", "box", "moon"]

BREEDS = [
    dict(id="siamese", fact=("Blue eyes and dark points", "Mavi gözler ve koyu uçlar"),
         ears="large", pattern=["points"], specials=["portrait", "walking"],
         palette=dict(b="#F2E3CF", d="#4A3B35", e="#5B9BD5", n="#D99A9A", w="#FBF8F3", o="#E07A5F", p="#9AA5B1", y="#F4D35E")),
    dict(id="british-shorthair", fact=("Round, plush and calm", "Yuvarlak, peluş ve sakin"),
         ears="small", pattern=[], head_w=0.4, specials=["teacup", "portrait"],
         palette=dict(b="#8E9AA6", d="#6E7A86", e="#E8A33D", n="#6E7A86", w="#DDE3E8", o="#F2E8DC", p="#C98B6B", y="#F4D35E")),
    dict(id="scottish-fold", fact=("Folded ears, owl-like face", "Katlanmış kulaklar, baykuş yüzü"),
         ears="folded", pattern=["tabby"], head_w=0.38, specials=["owl", "portrait"],
         palette=dict(b="#C9CDD2", d="#6F767D", e="#D9A441", n="#D9A0A0", w="#F2F2F2", o="#7FB3D5", p="#B0B7BF", y="#F4D35E")),
    dict(id="persian", fact=("Long coat and flat face", "Uzun tüyler ve basık yüz"),
         ears="small", pattern=[], fluffy=True, head_w=0.4, specials=["cushion", "portrait"],
         palette=dict(b="#EFE7DC", d="#D3C3AF", e="#3E8EDE", n="#E8A3A8", w="#FBF8F3", o="#8E5BA8", p="#E9C46A", y="#F4D35E")),
    dict(id="ragdoll", fact=("Goes limp when held", "Kucakta gevşeyip kalır"),
         ears="normal", pattern=["points", "mitts"], fluffy=True, specials=["bellyup", "portrait"],
         palette=dict(b="#F4EEE6", d="#8B7765", e="#4F86C6", n="#E2A3A3", w="#FBF8F3", o="#B5838D", p="#9AA5B1", y="#F4D35E")),
    dict(id="russian-blue", fact=("Silver-blue coat, green eyes", "Gümüş mavi tüy, yeşil gözler"),
         ears="large", pattern=[], specials=["night", "portrait"],
         palette=dict(b="#8FA3B5", d="#6F8396", e="#59B36B", n="#6E8090", w="#DCE3EA", o="#5C6B7A", p="#B8C4CF", y="#F1E3A0")),
    dict(id="abyssinian", fact=("Ticked coat and big ears", "Kırçıllı tüy ve iri kulaklar"),
         ears="large", pattern=["ticked"], specials=["bastet", "walking"],
         palette=dict(b="#C47F4F", d="#8C5532", e="#9CB84A", n="#C9705A", w="#F2D7B6", o="#E0B66A", p="#7D5A44", y="#E9C46A")),
    dict(id="birman", fact=("Sacred cat with white gloves", "Beyaz eldivenli kutsal kedi"),
         ears="normal", pattern=["points", "mitts"], fluffy=True, specials=["gloves", "sitting"],
         palette=dict(b="#F2E6D3", d="#6B5544", e="#3F7FCF", n="#D9A0A0", w="#FBF8F3", o="#C9A227", p="#9AA5B1", y="#F4D35E")),
    dict(id="bengal", fact=("Wild rosettes, loves to climb", "Vahşi benekler, tırmanmayı sever"),
         ears="normal", pattern=["spots"], specials=["jungle", "walking"],
         palette=dict(b="#E3A857", d="#5A3A22", e="#6FA04A", n="#B5654A", w="#F5E6C8", o="#3E7C4F", p="#8C6A4A", y="#F4D35E", g="#3E8E41")),
    dict(id="sphynx", fact=("Hairless and always warm", "Tüysüz ve hep sıcacık"),
         ears="large", pattern=[], specials=["sweater", "portrait"],
         palette=dict(b="#E9B8A7", d="#C98F7E", e="#7FB069", n="#D9827A", w="#F6DDD4", o="#5B7DB1", p="#F2C14E", y="#F4D35E")),
    dict(id="turkish-angora", fact=("Snow white, often odd-eyed", "Kar beyazı, çoğu zaman ela-mavi göz"),
         ears="normal", pattern=[], odd_eyes=True, fluffy=True, specials=["bow", "portrait"],
         palette=dict(b="#ECE8E1", d="#D6D1C8", e="#4F86C6", f="#E1B33F", n="#F2A3B0", w="#FBF8F3", o="#D1495B", p="#9AA5B1", y="#F4D35E")),
    dict(id="norwegian-forest", fact=("Thick coat for snowy woods", "Karlı ormanlar için kalın tüy"),
         ears="tufted", pattern=["tabby", "bib"], fluffy=True, specials=["forest", "bigtail"],
         palette=dict(b="#B07A4A", d="#6B4528", e="#8DB04A", n="#B5654A", w="#F3EDE4", o="#6B4F3A", p="#C8B6A6", y="#F4D35E", g="#2F6B3B")),
    dict(id="turkish-van", fact=("The cat that loves to swim", "Yüzmeyi seven kedi"),
         ears="normal", pattern=["van"], odd_eyes=True, specials=["swimming", "portrait"],
         palette=dict(b="#EFE9E0", d="#C2683A", e="#E1B33F", f="#4F86C6", n="#E8A3A8", w="#FBF8F3", o="#E07A5F", p="#9AA5B1", y="#F4D35E", u="#4A90C2")),
    dict(id="maine-coon", fact=("Gentle giant with lynx tufts", "Vaşak püsküllü nazik dev"),
         ears="tufted", pattern=["tabby", "bib"], fluffy=True, head_w=0.4, specials=["bigtail", "forest"],
         palette=dict(b="#8A6A4E", d="#4E3A2A", e="#C9A53F", n="#A0624A", w="#EFE6DA", o="#6B4F3A", p="#C8B6A6", y="#F4D35E", g="#2F6B3B")),
    dict(id="exotic-shorthair", fact=("A teddy bear in cat form", "Kedi kılığında oyuncak ayı"),
         ears="small", pattern=["tabby"], head_w=0.42, specials=["teddy", "cushion"],
         palette=dict(b="#E8B26A", d="#C47A2C", e="#B5652A", n="#D98A7A", w="#F7E7CF", o="#7A9E7E", p="#E9C46A", y="#F4D35E")),
]

BREEDS += [
    dict(id="burmese", fact=("Satin coat, golden eyes", "Saten tüy, altın gözler"),
         ears="normal", pattern=[], head_w=0.38, specials=["cushion", "portrait"],
         palette=dict(b="#6B4A35", d="#4F3526", e="#E5B53B", n="#8C5A4A", w="#D9C2AE", o="#B5838D", p="#C8B6A6")),
    dict(id="chartreux", fact=("Blue-grey with a gentle smile", "Gülümseyen mavi-gri kedi"),
         ears="small", pattern=[], head_w=0.4, specials=["teacup", "portrait"],
         palette=dict(b="#7F8C99", d="#66727E", e="#D98B2B", n="#5E6A75", w="#D5DCE2", o="#F2E8DC", p="#C98B6B")),
    dict(id="egyptian-mau", fact=("Natural spots, a born sprinter", "Doğal benekler, doğuştan koşucu"),
         ears="large", pattern=["spots"], specials=["bastet", "walking"],
         palette=dict(b="#C9CBC4", d="#4D4A44", e="#8DBF4A", n="#B87F72", w="#EDEDE6", o="#E0B66A", p="#7D5A44")),
    dict(id="manx", fact=("The tailless cat of the Isle of Man", "Man Adası'nın kuyruksuz kedisi"),
         ears="normal", pattern=["tabby"], tail="none", exclude=["bigtail"], head_w=0.4, specials=["sitting", "portrait"],
         palette=dict(b="#D9A066", d="#9C6233", e="#C9A53F", n="#C9705A", w="#F5E6D0", o="#5B8FB9", p="#9AA5B1")),
    dict(id="bombay", fact=("A pocket-sized panther", "Cep boyu bir panter"),
         ears="normal", pattern=[], specials=["night", "walking"],
         palette=dict(b="#2B2A2E", d="#1C1B1F", e="#D9822B", n="#4A4148", w="#55525A", o="#5C6B7A", p="#8E8A93", y="#F1E3A0")),
    dict(id="siberian", fact=("Triple coat for Siberian winters", "Sibirya kışına üç kat tüy"),
         ears="tufted", pattern=["tabby", "bib"], fluffy=True, head_w=0.4, specials=["forest", "bigtail"],
         palette=dict(b="#A58B6F", d="#5E4B3A", e="#8DB04A", n="#B5654A", w="#F1EBE2", o="#6B4F3A", p="#C8B6A6", g="#2F6B3B")),
    dict(id="devon-rex", fact=("Pixie ears and wavy fur", "Peri kulakları ve dalgalı tüy"),
         ears="large", pattern=[], head_w=0.34, specials=["sweater", "portrait"],
         palette=dict(b="#C8B8A6", d="#9C8B78", e="#D9A441", n="#D9827A", w="#EFE6DA", o="#7A9E7E", p="#F2C14E")),
    dict(id="oriental-shorthair", fact=("Sleek, talkative, all ears", "İnce, konuşkan, kocaman kulaklı"),
         ears="large", pattern=[], head_w=0.32, specials=["walking", "portrait"],
         palette=dict(b="#3F7A5A", d="#2E5C43", e="#8BC34A", n="#9C6B5A", w="#CFE3D6", o="#E07A5F", p="#9AA5B1")),
    dict(id="japanese-bobtail", fact=("Pom-pom tail, calico luck", "Ponpon kuyruk, üç renkli şans"),
         ears="normal", pattern=["patches"], tail="bob", exclude=["bigtail"], specials=["lucky", "portrait"],
         palette=dict(b="#F5F1EA", d="#E08A3C", k="#2E2A2B", e="#D9A441", n="#E59AA0", w="#FFFFFF", o="#D1495B", p="#9AA5B1")),
    dict(id="somali", fact=("The fox cat with a bushy tail", "Gür kuyruklu tilki kedi"),
         ears="large", pattern=["ticked"], fluffy=True, specials=["bigtail", "forest"],
         palette=dict(b="#C8743F", d="#8C4A24", e="#9CB84A", n="#C9705A", w="#F2D7B6", o="#E0B66A", p="#7D5A44", g="#3E7C4F")),
]

# Koleksiyon kartı bilgileri. Puanlar 1-5: enerji, sevgi, oyunculuk, bakım ihtiyacı.
# Kaynaklar türlerle ilgili genel kabul görmüş bilgiler; tartışmalı konularda temkinli ifade kullanıldı.
CARDS = {
    "siamese": (("Thailand", "Tayland"), "15–20", ("Short, colorpoint", "Kısa, uçları koyu"), (5, 5, 5, 1),
                ("One of the most talkative breeds: Siamese love to 'chat' with their people.",
                 "En konuşkan türlerden biri: insanlarıyla 'sohbet etmeyi' çok sever.")),
    "british-shorthair": (("United Kingdom", "Birleşik Krallık"), "12–17", ("Short, dense, plush", "Kısa, yoğun, peluş"), (2, 3, 2, 2),
                          ("Its round, smiling face is often said to have inspired the Cheshire Cat.",
                           "Yuvarlak, gülümseyen yüzünün Cheshire Kedisi'ne ilham verdiği söylenir.")),
    "scottish-fold": (("Scotland", "İskoçya"), "11–15", ("Short or long", "Kısa ya da uzun"), (3, 4, 3, 2),
                      ("Every Scottish Fold traces back to Susie, a farm cat found in Scotland in 1961.",
                       "Tüm Scottish Fold'lar 1961'de İskoçya'da bir çiftlikte bulunan Susie adlı kediden gelir.")),
    "persian": (("Iran (Persia)", "İran"), "12–17", ("Long and silky", "Uzun ve ipeksi"), (1, 4, 2, 5),
                ("Persians have been prized in Europe for their long coats since the 1600s.",
                 "İran kedileri uzun tüyleri nedeniyle 1600'lerden beri Avrupa'da çok değerlidir.")),
    "ragdoll": (("United States", "ABD"), "12–17", ("Semi-long, silky", "Yarı uzun, ipeksi"), (2, 5, 3, 3),
                ("Named for the way it goes limp like a rag doll when picked up.",
                 "Adını, kucağa alınınca bez bebek gibi gevşemesinden alır.")),
    "russian-blue": (("Russia", "Rusya"), "15–20", ("Short, dense double coat", "Kısa, yoğun çift kat"), (3, 3, 3, 1),
                     ("Its silver-tipped coat is so dense it stands out from the body.",
                      "Gümüş uçlu tüyü o kadar yoğundur ki gövdeden kabarık durur.")),
    "abyssinian": (("Named after Abyssinia (Ethiopia)", "Adını Habeşistan'dan (Etiyopya) alır"), "12–15", ("Short, ticked", "Kısa, kırçıllı"), (5, 4, 5, 1),
                   ("It looks like the cats of ancient Egyptian art, but genetics point to the Indian Ocean coast.",
                    "Antik Mısır sanatındaki kedilere benzer, ama genetik çalışmalar Hint Okyanusu kıyılarını işaret eder.")),
    "birman": (("Myanmar (Burma)", "Myanmar (Burma)"), "12–16", ("Semi-long, white gloves", "Yarı uzun, beyaz eldivenli"), (2, 5, 3, 3),
               ("Legend says a temple cat's paws turned white where they touched its dying priest.",
                "Efsaneye göre bir tapınak kedisinin, ölmekte olan rahibine dokunan patileri beyaza dönmüştür.")),
    "bengal": (("United States", "ABD"), "12–16", ("Short, spotted or marbled", "Kısa, benekli ya da mermer desenli"), (5, 3, 5, 1),
               ("Bred from domestic cats and the wild Asian leopard cat; many Bengals love water.",
                "Evcil kedilerle vahşi Asya leopar kedisinden geliştirildi; çoğu suyu çok sever.")),
    "sphynx": (("Canada", "Kanada"), "8–14", ("Hairless (fine peach fuzz)", "Tüysüz (ince şeftali tüyü)"), (4, 5, 4, 3),
               ("Not truly bald: a fine peach fuzz covers its warm skin, and it needs regular baths.",
                "Aslında tamamen tüysüz değildir; sıcak teni ince bir tüyle kaplıdır ve düzenli banyo ister.")),
    "turkish-angora": (("Türkiye (Ankara)", "Türkiye (Ankara)"), "12–18", ("Semi-long, silky", "Yarı uzun, ipeksi"), (4, 4, 5, 2),
                       ("One of the oldest natural breeds, treasured in Ankara for centuries; odd-colored eyes are common.",
                        "En eski doğal türlerden biri, Ankara'da yüzyıllardır el üstünde tutulur; farklı renkte gözler sık görülür.")),
    "norwegian-forest": (("Norway", "Norveç"), "12–16", ("Long, water-resistant double coat", "Uzun, su geçirmez çift kat"), (3, 4, 3, 3),
                         ("Norse legends tell of forest cats pulling the goddess Freya's chariot.",
                          "İskandinav efsanelerinde tanrıça Freya'nın arabasını orman kedileri çeker.")),
    "turkish-van": (("Türkiye (Lake Van)", "Türkiye (Van Gölü)"), "12–17", ("Semi-long, water-resistant", "Yarı uzun, su geçirmez"), (5, 3, 5, 2),
                    ("Nicknamed 'the swimming cat' for its love of water.",
                     "Suyu sevmesiyle 'yüzen kedi' olarak anılır.")),
    "maine-coon": (("United States (Maine)", "ABD (Maine)"), "12–15", ("Long, shaggy", "Uzun, gür"), (3, 4, 4, 3),
                   ("One of the largest domestic breeds; males can weigh more than 8 kg.",
                    "En iri evcil kedi türlerinden; erkekleri 8 kilonun üzerine çıkabilir.")),
    "exotic-shorthair": (("United States", "ABD"), "12–15", ("Short, plush", "Kısa, peluş"), (2, 4, 3, 2),
                         ("Often called 'a Persian in pajamas': the Persian look with an easy-care coat.",
                          "'Pijamalı İran kedisi' diye anılır: İran kedisi görünümü, bakımı kolay tüy.")),
    "burmese": (("Myanmar (Burma)", "Myanmar (Burma)"), "12–16", ("Short, satin", "Kısa, saten"), (4, 5, 4, 1),
                ("Modern Burmese descend from Wong Mau, a cat brought to the United States in 1930.",
                 "Modern Burmalar, 1930'da ABD'ye getirilen Wong Mau adlı kediden gelir.")),
    "chartreux": (("France", "Fransa"), "12–15", ("Short, woolly", "Kısa, yünümsü"), (2, 4, 3, 2),
                  ("A quiet French breed known for its 'smiling' face and copper eyes.",
                   "'Gülümseyen' yüzü ve bakır rengi gözleriyle bilinen sessiz bir Fransız türü.")),
    "egyptian-mau": (("Egypt", "Mısır"), "12–15", ("Short, naturally spotted", "Kısa, doğal benekli"), (5, 4, 4, 1),
                     ("One of the fastest house cats, said to sprint at around 48 km/h.",
                      "En hızlı ev kedilerinden; saatte 48 km civarında koşabildiği söylenir.")),
    "manx": (("Isle of Man", "Man Adası"), "8–14", ("Short or long", "Kısa ya da uzun"), (3, 4, 4, 2),
             ("Famous for being born without a tail; it runs with a rabbit-like hop.",
              "Kuyruksuz doğmasıyla ünlüdür; tavşan gibi seken bir koşusu vardır.")),
    "bombay": (("United States", "ABD"), "12–16", ("Short, glossy black", "Kısa, parlak siyah"), (3, 5, 4, 1),
               ("Bred to look like a miniature black panther, with copper eyes.",
                "Minyatür bir kara panter gibi görünmesi için geliştirildi; gözleri bakır rengidir.")),
    "siberian": (("Russia", "Rusya"), "11–18", ("Long, triple coat", "Uzun, üç katlı"), (4, 5, 4, 3),
                 ("Russia's national cat, with a thick triple coat for Siberian winters.",
                  "Rusya'nın ulusal kedisi; Sibirya kışları için kalın, üç katlı tüyü vardır.")),
    "devon-rex": (("England (Devon)", "İngiltere (Devon)"), "9–15", ("Short, wavy", "Kısa, dalgalı"), (5, 5, 5, 1),
                  ("Huge ears and wavy fur earn it the nickname 'pixie cat'.",
                   "Kocaman kulakları ve dalgalı tüyüyle 'peri kedisi' diye anılır.")),
    "oriental-shorthair": (("Thailand & United Kingdom", "Tayland ve Birleşik Krallık"), "12–15", ("Short, fine", "Kısa, ince"), (5, 5, 5, 1),
                           ("A Siamese cousin that comes in hundreds of colors and patterns.",
                            "Siyam'ın kuzeni; yüzlerce renk ve desende görülür.")),
    "japanese-bobtail": (("Japan", "Japonya"), "15–18", ("Short or long, often calico", "Kısa ya da uzun, çoğu üç renkli"), (4, 4, 5, 1),
                         ("The waving maneki-neko lucky cat figurines are modeled on this bobtailed breed.",
                          "El sallayan maneki-neko şans kedisi biblolarına bu kısa kuyruklu tür örnek alınır.")),
    "somali": (("North America", "Kuzey Amerika"), "12–16", ("Semi-long, ticked", "Yarı uzun, kırçıllı"), (5, 4, 5, 2),
               ("A long-haired Abyssinian, nicknamed the 'fox cat' for its bushy tail.",
                "Gür kuyruğu yüzünden 'tilki kedi' denen uzun tüylü bir Habeş kedisi.")),
}

TITLES = {
    "burmese": ("Burmese", "Burma Kedisi"), "chartreux": ("Chartreux", "Chartreux"),
    "egyptian-mau": ("Egyptian Mau", "Mısır Mau"), "manx": ("Manx", "Manx"), "bombay": ("Bombay", "Bombay"),
    "siberian": ("Siberian", "Sibirya Kedisi"), "devon-rex": ("Devon Rex", "Devon Rex"),
    "oriental-shorthair": ("Oriental Shorthair", "Oryantal Kısa Tüylü"),
    "japanese-bobtail": ("Japanese Bobtail", "Japon Bobtail"), "somali": ("Somali", "Somali"),
}


def rarity(order):
    return "common" if order <= 8 else "rare" if order <= 16 else "epic" if order <= 22 else "legendary"


def card_json(breed, order):
    (origin_en, origin_tr), lifespan, (coat_en, coat_tr), (energy, affection, play, grooming), (fact_en, fact_tr) = CARDS[breed["id"]]
    return {
        "number": order,
        "rarity": rarity(order),
        "origin": {"en": origin_en, "tr": origin_tr},
        "lifespan": lifespan,
        "coat": {"en": coat_en, "tr": coat_tr},
        "stats": {"energy": energy, "affection": affection, "playfulness": play, "grooming": grooming},
        "fact": {"en": fact_en, "tr": fact_tr},
    }


def portrait_json(breed):
    """Tür listesi ve kart için büyük, çözülmesi gerekmeyen piksel portre."""
    shapes = portrait({**breed, "size": 24})
    box = bounds(shapes)
    rows, cols = canvas_size(box, 24)
    pixels = rasterize(shapes, box, rows, cols)
    used = sorted({c for row in pixels for c in row if c != "."})
    return {"palette": {role: breed["palette"][role] for role in used}, "pixels": pixels}


# Türün paletinde olmayan sahne renkleri
SCENE_COLORS = dict(g="#4E8F4A", u="#4A90C2", y="#F4D35E", w="#FBF8F3", o="#E07A5F", p="#9AA5B1")
for _breed in BREEDS:
    _breed["palette"] = {**SCENE_COLORS, "f": _breed["palette"]["e"], **_breed["palette"]}

# Elle çizilmiş küçük bulmacalar: türün başına eklenir (id, başlık, piksel satırları)
HANDMADE = {
    "siamese": [
        ("siamese-001", ("Siamese Face", "Siyam Yüzü"), ["d...d", "ddddd", "b.b.b", "bbbbb", ".bdb."]),
        ("siamese-002", ("Curious Cat", "Meraklı Kedi"), ["...dd", "...d.", "bbbd.", "bbbb.", "b..b."]),
        ("siamese-003", ("Sitting Kitten", "Oturan Yavru"), [".d.d.", ".bbb.", "..b..", ".bbb.", "bbbbd"]),
        ("siamese-004", ("Blue Gaze", "Mavi Bakış"), ["d...d", "dd.dd", "beeeb", "bbbbb", "..d.."]),
        ("siamese-005", ("Tail Up", "Kuyruk Havada"), ["d.d.d", "ddd.d", "bbbbd", "bbbb.", "b..b."]),
    ],
}


MAX_SIZE = 15  # Telefonda yakınlaştırmasız rahat oynanan en büyük boyut


def size_range(order):
    """Tür sırasına göre ızgara boyutu: 5x5'ten başlayıp 15x15'e çıkar."""
    lo = min(MAX_SIZE, 5 + int((order - 1) * 0.45))
    hi = min(MAX_SIZE, lo + 3)
    return lo, hi


def motif_plan(breed, count):
    """Küçük boyutlarda basit nesneler, büyüklerde sahneler; türe özgü motiflerden biri
    bölümün ortasında, diğeri finalde."""
    specials = breed["specials"]
    simple = ["paw", "heart", "fish", "yarn", "bowl", "mouse", "fishbone"]
    scenes = [s for s in ("portrait", "sleeping", "sitting", "walking", "box", "moon") if s not in specials]
    pool = simple + scenes
    plan = [pool[i % len(pool)] for i in range(count - 2)]
    plan.insert(round(len(plan) * 0.6), specials[0])
    plan.append(specials[-1])
    return plan


def is_good(pixels):
    solution = [[c != "." for c in row] for row in pixels]
    rows, cols = len(solution), len(solution[0])
    ratio = sum(map(sum, solution)) / (rows * cols)
    if not 0.25 <= ratio <= 0.85:
        return False
    # Resim tuvali doldurmalı: en fazla bir boş satır/sütun
    if sum(1 for row in solution if not any(row)) > 1 or sum(1 for col in zip(*solution) if not any(col)) > 1:
        return False
    return solve_logically([clue(r) for r in solution], [clue(c) for c in zip(*solution)]) == solution


def generate_breed(breed, order):
    puzzles = []
    used = set()
    for pid, (en, tr), pixels in HANDMADE.get(breed["id"], []):
        puzzles.append(make_puzzle(pid, en, tr, pixels, breed))
        used.add(silhouette(pixels))
    count = PUZZLES_PER_BREED - len(puzzles)
    lo, hi = size_range(order)
    if puzzles:
        lo = min(hi, lo + 1)
    sizes = [round(lo + (hi - lo) * i / max(count - 1, 1)) for i in range(count)]
    plan = motif_plan(breed, count)
    usage = {}
    for n, motif in zip(sizes, plan):
        number = len(puzzles) + 1
        found = None
        # Plandaki motif bu boyutta okunmuyorsa ya da çözülemiyorsa en az kullanılan uygun motife geç
        excluded = set(breed.get("exclude", []))
        fallbacks = sorted(set(COMMON + breed["specials"]) - {motif} - excluded, key=lambda m: (usage.get(m, 0), m))
        for name in [motif] + fallbacks:
            if n < MIN_SIZE.get(name, 0):
                continue
            draw, en, tr = MOTIFS[name]
            shapes = draw({**breed, "size": n})
            box = bounds(shapes)
            rows, cols = canvas_size(box, n)
            rng = random.Random(f"{breed['id']}-{number}-{name}")
            for attempt in range(24):
                jitter = attempt > 0
                pixels = rasterize(
                    shapes, box, rows, cols,
                    mirror=attempt % 2 == 1,
                    scale=rng.uniform(0.92, 1.0) if jitter else 1.0,
                    dx=rng.uniform(-0.03, 0.03) if jitter else 0.0,
                    dy=rng.uniform(-0.03, 0.03) if jitter else 0.0,
                )
                key = silhouette(pixels)
                if key not in used and is_good(pixels):
                    found = (en, tr, pixels)
                    used.add(key)
                    usage[name] = usage.get(name, 0) + 1
                    break
            if found:
                break
        if not found:
            raise SystemExit(f"{breed['id']} #{number} ({n}) için çözülebilir bulmaca bulunamadı")
        en, tr, pixels = found
        puzzles.append(make_puzzle(f"{breed['id']}-{number:03d}", en, tr, pixels, breed))
    return puzzles


def silhouette(pixels):
    return tuple("".join("#" if c != "." else "." for c in row) for row in pixels)


def make_puzzle(pid, en, tr, pixels, breed):
    used = sorted({c for row in pixels for c in row if c != "."})
    return {
        "id": pid,
        "title": {"en": en, "tr": tr},
        "palette": {role: breed["palette"][role] for role in used},
        "pixels": pixels,
    }


def write_json(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


def main():
    catalog_path = PUZZLES / "catalog.json"
    catalog = json.loads(catalog_path.read_text())
    titles = {c["id"]: c for c in catalog["chapters"]}
    chapters = [titles["tutorial"]]
    for order, breed in enumerate(BREEDS, 1):
        entry = titles.get(breed["id"], {})
        file = f"chapter_{order:02d}_{breed['id'].replace('-', '_')}"
        title = entry.get("title") or dict(zip(("en", "tr"), TITLES[breed["id"]]))
        chapters.append({
            "id": breed["id"],
            "kind": "breed",
            "title": title,
            "subtitle": {"en": breed["fact"][0], "tr": breed["fact"][1]},
            "accentColor": entry.get("accentColor", breed["palette"]["b"]),
            "file": file,
            "portrait": portrait_json(breed),
            "card": card_json(breed, order),
        })
        puzzles = generate_breed(breed, order)
        write_json(PUZZLES / f"{file}.json", {"schemaVersion": 1, "chapterID": breed["id"], "puzzles": puzzles})
        sizes = sorted({len(p["pixels"]) for p in puzzles})
        print(f"✓ {breed['id']}: {len(puzzles)} bulmaca, {sizes[0]}x{sizes[0]} – {sizes[-1]}x{sizes[-1]}")
    catalog["chapters"] = chapters
    write_json(catalog_path, catalog)


if __name__ == "__main__":
    main()
