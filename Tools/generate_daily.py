#!/usr/bin/env python3
"""Günlük bulmaca havuzunu üretir (yalnızca Python 3 standart kütüphanesi).

Kullanım:  python3 Tools/generate_daily.py

Kedi dışı, simetrik "uzman" desenler: genişlik en fazla 10, yükseklik 10-20. Her desen
tahmin yapmadan çözülebilir (yani tek çözümlü) ve çözücünün birçok tur gerektirdiği,
zorlayıcı olanlar seçilir. Uygulama günü tarihten hesaplar; herkes aynı gün aynı bulmacayı
oynar. Çıktı deterministiktir: Catgrid/Resources/Puzzles/daily.json
"""
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_puzzles import clue, solve_line  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Catgrid/Resources/Puzzles/daily.json"
COUNT = 366
SIZES = [(10, 10), (10, 12), (10, 15), (10, 15), (10, 18), (10, 20), (8, 12), (9, 14), (10, 20)]
# Kenar rengi (koyu) ve iç renk (açık)
PALETTES = [
    ("#3D5A80", "#98C1D9"), ("#6D2E46", "#D5B9B2"), ("#2A6F4F", "#9BD3AE"), ("#7B4B94", "#C9B6E4"),
    ("#B5523B", "#F2C49B"), ("#264653", "#E9C46A"), ("#5C3D2E", "#E0B589"), ("#1D3557", "#E63946"),
    ("#3A5A40", "#DAD7CD"), ("#6A4C93", "#FFCA3A"), ("#0B6E4F", "#F4D35E"), ("#8C2F39", "#FEC5BB"),
]
TITLES = [
    {"en": "Mosaic", "tr": "Mozaik", "ja": "モザイク", "de": "Mosaik", "fr": "Mosaïque", "es": "Mosaico", "pt-BR": "Mosaico", "ko": "모자이크"},
    {"en": "Totem", "tr": "Totem", "ja": "トーテム", "de": "Totem", "fr": "Totem", "es": "Tótem", "pt-BR": "Totem", "ko": "토템"},
    {"en": "Lantern", "tr": "Fener", "ja": "ランタン", "de": "Laterne", "fr": "Lanterne", "es": "Farol", "pt-BR": "Lanterna", "ko": "등불"},
    {"en": "Tapestry", "tr": "Duvar Halısı", "ja": "タペストリー", "de": "Wandteppich", "fr": "Tapisserie", "es": "Tapiz", "pt-BR": "Tapeçaria", "ko": "태피스트리"},
    {"en": "Ornament", "tr": "Süsleme", "ja": "オーナメント", "de": "Ornament", "fr": "Ornement", "es": "Ornamento", "pt-BR": "Ornamento", "ko": "장식"},
    {"en": "Crystal", "tr": "Kristal", "ja": "クリスタル", "de": "Kristall", "fr": "Cristal", "es": "Cristal", "pt-BR": "Cristal", "ko": "크리스털"},
    {"en": "Labyrinth", "tr": "Labirent", "ja": "迷宮", "de": "Labyrinth", "fr": "Labyrinthe", "es": "Laberinto", "pt-BR": "Labirinto", "ko": "미궁"},
    {"en": "Kilim", "tr": "Kilim", "ja": "キリム", "de": "Kelim", "fr": "Kilim", "es": "Kilim", "pt-BR": "Kilim", "ko": "킬림"},
    {"en": "Stained Glass", "tr": "Vitray", "ja": "ステンドグラス", "de": "Buntglas", "fr": "Vitrail", "es": "Vitral", "pt-BR": "Vitral", "ko": "스테인드글라스"},
    {"en": "Snowflake", "tr": "Kar Tanesi", "ja": "雪の結晶", "de": "Schneeflocke", "fr": "Flocon", "es": "Copo de nieve", "pt-BR": "Floco de Neve", "ko": "눈송이"},
    {"en": "Mask", "tr": "Maske", "ja": "仮面", "de": "Maske", "fr": "Masque", "es": "Máscara", "pt-BR": "Máscara", "ko": "가면"},
    {"en": "Emblem", "tr": "Amblem", "ja": "紋章", "de": "Emblem", "fr": "Emblème", "es": "Emblema", "pt-BR": "Emblema", "ko": "엠블럼"},
]


def solve_with_passes(row_clues, col_clues):
    """Satır mantığıyla çözer; (çözüm, tur sayısı). Tur sayısı zorluğun ölçüsüdür."""
    rows, cols = len(row_clues), len(col_clues)
    grid = [[None] * cols for _ in range(rows)]
    passes, changed = 0, True
    while changed:
        changed = False
        passes += 1
        for r in range(rows):
            solved = solve_line(grid[r], row_clues[r])
            if solved is None:
                return None, passes
            if solved != grid[r]:
                grid[r], changed = solved, True
        for c in range(cols):
            column = [grid[r][c] for r in range(rows)]
            solved = solve_line(column, col_clues[c])
            if solved is None:
                return None, passes
            if solved != column:
                for r in range(rows):
                    grid[r][c] = solved[r]
                changed = True
    return grid, passes


def smooth(grid, rng):
    rows, cols = len(grid), len(grid[0])
    out = [row[:] for row in grid]
    for r in range(rows):
        for c in range(cols):
            n = sum(grid[rr][cc] for rr in range(r - 1, r + 2) for cc in range(c - 1, c + 2)
                    if 0 <= rr < rows and 0 <= cc < cols)
            if n >= 6:
                out[r][c] = True
            elif n <= 3:
                out[r][c] = False
    return out


def candidate(rng, cols, rows):
    half = (cols + 1) // 2
    density = rng.uniform(0.48, 0.6)
    grid = [[rng.random() < density for _ in range(half)] for _ in range(rows)]
    for _ in range(rng.choice([1, 1, 2])):
        grid = smooth(grid, rng)
    full = []
    for row in grid:
        mirrored = row[: cols // 2][::-1]
        full.append(row + mirrored if cols % 2 == 0 else row + row[:-1][::-1])
    if rng.random() < 0.3:  # dikey simetri de: daha "amblem" görünümü
        for r in range(rows // 2):
            full[rows - 1 - r] = full[r][:]
    return full


def acceptable(grid):
    rows, cols = len(grid), len(grid[0])
    filled = sum(map(sum, grid)) / (rows * cols)
    if not 0.42 <= filled <= 0.68:
        return False
    empty_rows = sum(not any(row) for row in grid)
    empty_cols = sum(not any(col) for col in zip(*grid))
    full_rows = sum(all(row) for row in grid)
    return empty_rows == 0 and empty_cols == 0 and full_rows <= 1


def color(grid):
    """Kenardaki kareler koyu (a), içtekiler açık (b)."""
    rows, cols = len(grid), len(grid[0])
    lines = []
    for r in range(rows):
        line = ""
        for c in range(cols):
            if not grid[r][c]:
                line += "."
                continue
            edge = any(not (0 <= r + dr < rows and 0 <= c + dc < cols) or not grid[r + dr][c + dc]
                       for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            line += "a" if edge else "b"
        lines.append(line)
    return lines


def main():
    rng = random.Random(20261009)
    puzzles, seen = [], set()
    while len(puzzles) < COUNT:
        cols, rows = SIZES[len(puzzles) % len(SIZES)]
        best = None
        for _ in range(400):
            grid = candidate(rng, cols, rows)
            key = "".join("".join("#" if x else "." for x in row) for row in grid)
            if key in seen or not acceptable(grid):
                continue
            row_clues = [clue(row) for row in grid]
            col_clues = [clue(col) for col in zip(*grid)]
            solved, passes = solve_with_passes(row_clues, col_clues)
            if solved != grid:
                continue
            if best is None or passes > best[1]:
                best = (grid, passes, key)
            if passes >= 6:
                break
        if best is None:
            continue
        grid, passes, key = best
        seen.add(key)
        index = len(puzzles)
        dark, light = PALETTES[index % len(PALETTES)]
        puzzles.append({
            "id": f"daily-pool-{index + 1:03d}",
            "title": TITLES[(index * 7) % len(TITLES)],
            "palette": {"a": dark, "b": light},
            "pixels": color(grid),
        })
        if len(puzzles) % 50 == 0:
            print(f"{len(puzzles)} desen", file=sys.stderr)
    OUT.write_text(json.dumps({"schemaVersion": 1, "chapterID": "daily", "puzzles": puzzles},
                              ensure_ascii=False, indent=1) + "\n")
    print(f"✓ {len(puzzles)} günlük bulmaca → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
