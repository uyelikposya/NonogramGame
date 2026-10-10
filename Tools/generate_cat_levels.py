#!/usr/bin/env python3
"""Kedi Bulmaca bölümlerini üretir → Catgrid/Resources/Puzzles/cat_levels.json

Kurallar: NxN tahta N renge bölünmüş. Her renkte, her satırda ve her sütunda tam 1 kedi;
kediler birbirine (çapraz dahil) değemez.

Her bölüm:
- tek çözümlüdür (geri izlemeli sayım),
- tahmin gerektirmez: uygulamadaki ipucu kurallarıyla (CatDeduction.swift ile aynı) baştan
  sona çözülür,
- zorluğa göre (en güçlü gereken kural, adım sayısı) kendi boyutu içinde sıralanır,
- 26 türün havuzundan rastgele seçilmiş, birbirinden farklı N kedi türü taşır.

Kullanım: python3 Tools/generate_cat_levels.py [--seed 7]
Belirli bir tohumla her çalıştırmada aynı bölümler çıkar.
"""
import argparse
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Catgrid/Resources/Puzzles/cat_levels.json"
CATALOG = ROOT / "Catgrid/Resources/Puzzles/catalog.json"

# Boyut → bölüm sayısı (toplam 335)
PLAN = [(5, 25), (6, 35), (7, 40), (8, 45), (9, 45), (10, 40), (11, 30), (12, 25), (13, 20), (14, 15), (15, 15)]

LETTERS = "abcdefghijklmnopqrstuvwxyz"

# Eğitim bölümü (1. bölüm): sol üstteki tek kareli renk hemen kedi; her kedi bir sonrakini
# tek seçeneğe indirir (uygulamadaki adım adım eğitim bu sırayı izler).
TUTORIAL = {
    "regions": ["abbcc", "dbbcc", "ddccc", "dddee", "eeeee"],
}


# MARK: - Çözüm sayma

def masks(n, region):
    """Bit maskeleri: her kare için saldırı maskesi (kendisi dahil) ve 3n grup (satır, sütun, renk)."""
    rows = [((1 << n) - 1) << (r * n) for r in range(n)]
    cols = [0] * n
    regs = [0] * n
    for r in range(n):
        for c in range(n):
            bit = 1 << (r * n + c)
            cols[c] |= bit
            regs[region[r][c]] |= bit
    groups = rows + cols + regs
    atk = []
    for r in range(n):
        for c in range(n):
            m = rows[r] | cols[c] | regs[region[r][c]]
            for rr in (r - 1, r, r + 1):
                if 0 <= rr < n:
                    for cc in (c - 1, c, c + 1):
                        if 0 <= cc < n:
                            m |= 1 << (rr * n + cc)
            atk.append(m)
    return groups, atk


_NATIVE = None


def _native():
    """Tools/native/catsolver.c derlenebilirse C sayacı kullanılır (çok daha hızlı)."""
    global _NATIVE
    if _NATIVE is None:
        import ctypes
        import subprocess
        import tempfile
        try:
            src = Path(__file__).resolve().parent / "native/catsolver.c"
            lib = Path(tempfile.gettempdir()) / "catsolver.so"
            if not lib.exists() or lib.stat().st_mtime < src.stat().st_mtime:
                subprocess.run(["cc", "-O3", "-shared", "-fPIC", "-o", str(lib), str(src)], check=True)
            _NATIVE = ctypes.CDLL(str(lib))
        except Exception as error:  # derleyici yoksa Python'a dön
            print(f"C hızlandırma yok ({error}); Python kullanılıyor", file=sys.stderr)
            _NATIVE = False
    return _NATIVE


def find_solutions(n, region, limit=2):
    native = _native()
    if native:
        import ctypes
        flat = (ctypes.c_int * (n * n))(*[g for row in region for g in row])
        out = (ctypes.c_int * (n * limit))()
        count = native.find_solutions(n, flat, limit, out)
        return [list(out[k * n:(k + 1) * n]) for k in range(count)]
    return find_solutions_py(n, region, limit)


def find_solutions_py(n, region, limit=2):
    """En kısıtlı grubu (en az adaylı satır/sütun/renk) önce dener; bit maskeleriyle hızlı."""
    groups, atk = masks(n, region)
    sols = []
    full = (1 << (n * n)) - 1

    def rec(cand, closed, placed):
        if len(placed) == n:
            sols.append(sorted(placed))
            return len(sols) >= limit
        best = None
        best_count = 10 ** 9
        for i, gm in enumerate(groups):
            if closed >> i & 1:
                continue
            k = (cand & gm).bit_count()
            if k < best_count:
                best, best_count = i, k
                if k <= 1:
                    break
        if best_count == 0:
            return False
        options = cand & groups[best]
        while options:
            low = options & -options
            cell = low.bit_length() - 1
            options ^= low
            r, c = divmod(cell, n)
            cl = closed | (1 << r) | (1 << (n + c)) | (1 << (2 * n + region[r][c]))
            placed.append(cell)
            if rec(cand & ~atk[cell], cl, placed):
                return True
            placed.pop()
        return False

    rec(full, 0, [])
    out = []
    for cells in sols:
        cols = [0] * n
        for cell in cells:
            r, c = divmod(cell, n)
            cols[r] = c
        out.append(cols)
    return out


def count_solutions(n, region, limit=2):
    return len(find_solutions(n, region, limit))


# MARK: - Mantıkla çözme (uygulamadaki ipucu kurallarıyla aynı)

def neighbors(n, r, c):
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            if (dr or dc) and 0 <= r + dr < n and 0 <= c + dc < n:
                yield r + dr, c + dc


def attack(n, region, r, c):
    """(r, c)'ye kedi konunca kedi olamayacak kareler."""
    out = set()
    g = region[r][c]
    for i in range(n):
        out.add((r, i))
        out.add((i, c))
    for rr in range(n):
        for cc in range(n):
            if region[rr][cc] == g:
                out.add((rr, cc))
    out.update(neighbors(n, r, c))
    out.discard((r, c))
    return out


def groups(n, region):
    """Her kısıt grubu: satırlar, sütunlar, renkler (kare kümeleri)."""
    gs = []
    for r in range(n):
        gs.append(("row", r, [(r, c) for c in range(n)]))
    for c in range(n):
        gs.append(("col", c, [(r, c) for r in range(n)]))
    for g in range(n):
        gs.append(("region", g, [(r, c) for r in range(n) for c in range(n) if region[r][c] == g]))
    return gs


def deduce(n, region, max_level=3):
    """Kurallar sırayla denenir; en düşük seviyeli işe yarayan uygulanır.
    0: tek aday kalan grup → kedi (ve saldırdığı kareler elenir)
    1: k renk k satıra/sütuna sığıyor → o satır/sütunların geri kalanı elenir (ve tersi), k ≤ 3
    2: bir kareye kedi konursa bir grupta aday kalmıyor → kare elenir
    3: iki adımlı deneme (kedi koy, tek adayları zincirle, çelişki ara)
    Döner: (çözüldü mü, kullanılan en yüksek seviye, adım sayısı)."""
    cand = {(r, c) for r in range(n) for c in range(n)}
    cats = set()
    gs = groups(n, region)
    hardest = 0
    steps = 0

    def place(cell):
        cats.add(cell)
        cand.difference_update(attack(n, region, *cell))
        cand.discard(cell)

    def live(cells):
        return [x for x in cells if x in cand]

    def group_has_cat(cells):
        return any(x in cats for x in cells)

    while len(cats) < n:
        progressed = False
        # 0: tek aday
        for _, _, cells in gs:
            if group_has_cat(cells):
                continue
            lv = live(cells)
            if not lv:
                return False, hardest, steps
            if len(lv) == 1:
                place(lv[0])
                steps += 1
                progressed = True
                break
        if progressed:
            continue
        # 1: k renk ↔ k satır (ve sütun) kısıtlaması
        removed = rule_confinement(n, region, cand, cats)
        if removed:
            cand.difference_update(removed)
            hardest = max(hardest, 1)
            steps += 1
            continue
        if max_level < 2:
            return False, hardest, steps
        # 2: bir kareye kedi grubu boşaltıyor
        removed = set()
        for cell in sorted(cand):
            hit = attack(n, region, *cell) | {cell}
            for _, _, cells in gs:
                if group_has_cat(cells) or cell in cells:
                    continue
                if all(x in hit for x in live(cells)):
                    removed.add(cell)
                    break
        if removed:
            cand.difference_update(removed)
            hardest = max(hardest, 2)
            steps += 1
            continue
        if max_level < 3:
            return False, hardest, steps
        # 3: kısa deneme zinciri
        removed = set()
        for cell in sorted(cand):
            if contradicts(n, region, gs, set(cand), set(cats), cell):
                removed.add(cell)
        if removed:
            cand.difference_update(removed)
            hardest = max(hardest, 3)
            steps += 1
            continue
        return False, hardest, steps
    return True, hardest, steps


def contradicts(n, region, gs, cand, cats, cell):
    cats.add(cell)
    cand.difference_update(attack(n, region, *cell))
    cand.discard(cell)
    for _ in range(n):
        changed = False
        for _, _, cells in gs:
            if any(x in cats for x in cells):
                continue
            lv = [x for x in cells if x in cand]
            if not lv:
                return True
            if len(lv) == 1:
                cats.add(lv[0])
                cand.difference_update(attack(n, region, *lv[0]))
                cand.discard(lv[0])
                changed = True
        if not changed:
            break
    return False


def rule_confinement(n, region, cand, cats):
    """k renk tamamen k satırın (sütunun) içindeyse o satırların diğer adayları elenir;
    k satırın adayları k rengin içindeyse o renklerin diğer adayları elenir."""
    from itertools import combinations
    open_regions = [g for g in range(n) if not any(region[r][c] == g for r, c in cats)]
    reg_cells = {g: [(r, c) for (r, c) in cand if region[r][c] == g] for g in open_regions}
    for axis in (0, 1):
        open_lines = [i for i in range(n) if not any(x[axis] == i for x in cats)]
        line_cells = {i: [x for x in cand if x[axis] == i] for i in open_lines}
        for k in (1, 2, 3):
            # renkler → çizgiler
            for combo in combinations(open_regions, k):
                lines = {x[axis] for g in combo for x in reg_cells[g]}
                if len(lines) == k:
                    removed = {x for i in lines for x in line_cells.get(i, []) if region[x[0]][x[1]] not in combo}
                    if removed:
                        return removed
            # çizgiler → renkler
            for combo in combinations(open_lines, k):
                regs = {region[x[0]][x[1]] for i in combo for x in line_cells[i]}
                if len(regs) == k:
                    removed = {x for g in regs for x in reg_cells.get(g, []) if x[axis] not in combo}
                    if removed:
                        return removed
    return set()


# MARK: - Üretim

def random_solution(n, rng):
    """Her satırda bir kedi, sütunlar farklı, ardışık satırlar komşu değil."""
    order = list(range(n))
    for _ in range(1000):
        cols = []
        used = set()

        def rec(r):
            if r == n:
                return True
            options = order[:]
            rng.shuffle(options)
            for c in options:
                if c in used or (cols and abs(cols[-1] - c) <= 1):
                    continue
                cols.append(c)
                used.add(c)
                if rec(r + 1):
                    return True
                cols.pop()
                used.discard(c)
            return False

        if rec(0):
            return cols
    raise RuntimeError("çözüm bulunamadı")


def grow_regions(n, sol, rng):
    region = [[-1] * n for _ in range(n)]
    frontier = {}
    for g, c in enumerate(sol):
        region[g][c] = g
    # Renkler farklı hızlarda büyüsün: biri küçük, biri büyük kalabilsin
    weights = [rng.uniform(0.3, 3.0) for _ in range(n)]
    remaining = n * n - n
    while remaining:
        g = rng.choices(range(n), weights=weights)[0]
        cells = [(r, c) for r in range(n) for c in range(n) if region[r][c] == g]
        options = [(rr, cc) for r, c in cells for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1))
                   if 0 <= rr < n and 0 <= cc < n and region[rr][cc] == -1]
        if not options:
            weights[g] = 0.0001
            if all(w <= 0.0001 for w in weights):
                return None
            continue
        rr, cc = rng.choice(options)
        region[rr][cc] = g
        remaining -= 1
    return region


def connected_without(n, region, g, removed):
    cells = [(r, c) for r in range(n) for c in range(n) if region[r][c] == g and (r, c) != removed]
    if not cells:
        return False
    seen = {cells[0]}
    stack = [cells[0]]
    cellset = set(cells)
    while stack:
        r, c = stack.pop()
        for x in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
            if x in cellset and x not in seen:
                seen.add(x)
                stack.append(x)
    return len(seen) == len(cells)


def make_unique(n, region, sol, rng, tries=400):
    """Başka çözümler varsa, onların en sık kullandığı (çözümümüzde kedi olmayan) bir kareyi
    komşu renge aktararak bozar; tek çözüm kalana kadar tekrarlar."""
    cat_cells = {(r, c) for r, c in enumerate(sol)}
    for _ in range(tries):
        sols = find_solutions(n, region, limit=24)
        others = [s for s in sols if s != sol]
        if not others:
            return region if len(sols) == 1 else None
        counts = {}
        for other in others:
            for r, c in enumerate(other):
                if (r, c) not in cat_cells:
                    counts[(r, c)] = counts.get((r, c), 0) + 1
        cells = sorted(counts, key=lambda x: (-counts[x], rng.random()))
        moved = False
        for r, c in cells[:12]:
            g = region[r][c]
            if not connected_without(n, region, g, (r, c)):
                continue
            targets = {region[rr][cc] for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1))
                       if 0 <= rr < n and 0 <= cc < n and region[rr][cc] != g}
            if not targets:
                continue
            region[r][c] = rng.choice(sorted(targets))
            moved = True
            break
        if not moved:
            return None
    return None


def generate(n, rng, max_level):
    while True:
        sol = random_solution(n, rng)
        region = grow_regions(n, sol, rng)
        if region is None:
            continue
        region = make_unique(n, region, sol, rng)
        if region is None:
            continue
        solved, hardest, steps = deduce(n, region, max_level=max_level)
        if not solved:
            continue
        return region, sol, hardest, steps


def encode(region):
    return ["".join(LETTERS[g] for g in row) for row in region]


def make_level(task):
    """Bir bölüm adayı (paralel çalışır): (boyut, sıra, tohum) → bölüm."""
    n, index, seed = task
    rng = random.Random(seed)
    # Küçük tahtalarda yalnızca kolay kurallar; büyüdükçe daha zor bölümler kabul edilir
    max_level = 1 if n <= 5 else (2 if n <= 8 else 3)
    region, sol, hardest, steps = generate(n, rng, max_level)
    return n, index, encode(region), sol, hardest, steps


def main():
    from multiprocessing import Pool

    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    rng = random.Random(args.seed)

    catalog = json.loads(CATALOG.read_text())
    breeds = [ch["id"] for ch in catalog["chapters"] if ch["kind"] == "breed"]
    assert len(breeds) >= 15, "en az 15 tür gerekli"

    # Yedek adaylar: aynı bölüm iki kez çıkarsa yerine geçer
    tasks = [(n, i, args.seed * 100_000 + n * 1000 + i) for n, count in PLAN for i in range(count + 3)]
    tasks.sort(key=lambda t: -t[0])  # büyükler önce başlasın
    results = {}
    with Pool() as pool:
        for n, index, regions, sol, hardest, steps in pool.imap_unordered(make_level, tasks):
            results.setdefault(n, []).append((index, regions, sol, hardest, steps))
            print(f"  {n}x{n} #{index} (zorluk {hardest}, {steps} adım)", file=sys.stderr, flush=True)

    tutorial_region = [[LETTERS.index(ch) for ch in row] for row in TUTORIAL["regions"]]
    sols = find_solutions(5, tutorial_region, limit=2)
    assert len(sols) == 1, "eğitim bölümü tek çözümlü olmalı"
    solved, _, _ = deduce(5, tutorial_region, max_level=0)
    assert solved, "eğitim bölümü yalnızca tek seçenek kuralıyla çözülmeli"

    levels = []
    number = 0
    for n, count in PLAN:
        seen = set()
        batch = []
        if n == 5:
            batch.append((-1, TUTORIAL["regions"], sols[0], 0))
            seen.add(tuple(TUTORIAL["regions"]))
        for index, regions, sol, hardest, steps in sorted(results[n]):
            if len(batch) == count:
                break
            if tuple(regions) in seen:
                continue
            seen.add(tuple(regions))
            batch.append((hardest * 100 + steps, regions, sol, hardest))
        assert len(batch) == count, f"{n}x{n}: yeterli farklı bölüm yok"
        # Boyut içinde kolaydan zora (eğitim hep ilk)
        batch.sort(key=lambda x: x[0])
        for _, regions, sol, hardest in batch:
            number += 1
            levels.append({
                "id": f"cat-{number:03d}",
                "size": n,
                "regions": regions,
                "solution": sol,
                "breeds": rng.sample(breeds, n),
                "difficulty": hardest,
            })

    OUT.write_text(json.dumps({"schemaVersion": 1, "levels": levels}, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"{len(levels)} bölüm → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
