#!/usr/bin/env python3
"""Uygulama simgesini çizer (Pillow gerekir): 1024x1024, şeffaflıksız PNG.

Kullanım:  pip install pillow && python3 Tools/generate_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Catgrid/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
# Ana sayfa başlığındaki logo: simgenin aynısı (uygulama içinde görüntü olarak kullanılır)
LOGO = ROOT / "Catgrid/Resources/Assets.xcassets/AppLogo.imageset"
SIZE = 1024
SS = 4  # kenar yumuşatma için 4 kat büyük çizip küçültülür
S = SIZE * SS


def p(x, y):
    return (x * SS, y * SS)


def box(cx, cy, rx, ry):
    return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]


def main():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)

    # Sıcak pastel degrade zemin
    top, bottom = (255, 214, 196), (246, 150, 140)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))

    # Nonogram ızgarasını hatırlatan hafif kareler
    cell, gap = 112, 14
    pattern = ["#.#.#", ".###.", "#####", ".#.#.", "#...#"]
    ox, oy = 512 - (5 * cell + 4 * gap) / 2, 40
    for r, row in enumerate(pattern):
        for c, ch in enumerate(row):
            x, y = ox + c * (cell + gap), oy + r * (cell + gap)
            color = (255, 235, 226) if ch == "#" else (250, 196, 182)
            d.rounded_rectangle([x * SS, y * SS, (x + cell) * SS, (y + cell) * SS], radius=22 * SS, fill=color)

    # Yavru kedi
    fur, stripe, inner, cream, dark = (247, 190, 128), (226, 146, 82), (247, 168, 176), (255, 243, 228), (59, 47, 47)

    # Gölge
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).ellipse(box(512, 650, 340, 300), fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40 * SS))
    img.paste((190, 90, 80), (0, 18 * SS), shadow)

    # Kulaklar
    for side in (-1, 1):
        outer = [p(512 + side * 300, 470), p(512 + side * 250, 165), p(512 + side * 80, 330)]
        d.polygon(outer, fill=fur)
        d.polygon([p(512 + side * 265, 420), p(512 + side * 240, 230), p(512 + side * 130, 335)], fill=inner)

    # Baş ve yanak tüyleri
    d.ellipse(box(512, 610, 335, 290), fill=fur)
    for side in (-1, 1):
        d.polygon([p(512 + side * 300, 640), p(512 + side * 365, 700), p(512 + side * 290, 720)], fill=fur)

    # Alındaki tekir çizgileri
    for x, h in ((452, 120), (512, 140), (572, 120)):
        d.rounded_rectangle([(x - 16) * SS, 350 * SS, (x + 16) * SS, (350 + h) * SS], radius=16 * SS, fill=stripe)

    # Ağız çevresi
    d.ellipse(box(512, 735, 150, 100), fill=cream)

    # Pembe yanaklar
    blush = Image.new("L", (S, S), 0)
    bd = ImageDraw.Draw(blush)
    for side in (-1, 1):
        bd.ellipse(box(512 + side * 215, 700, 55, 34), fill=150)
    blush = blush.filter(ImageFilter.GaussianBlur(10 * SS))
    img.paste((246, 140, 150), (0, 0), blush)

    # Gözler: büyük, parlak
    for side in (-1, 1):
        cx = 512 + side * 125
        d.ellipse(box(cx, 600, 62, 76), fill=dark)
        d.ellipse(box(cx - 18, 575, 22, 24), fill=(255, 255, 255))
        d.ellipse(box(cx + 20, 628, 9, 9), fill=(255, 255, 255))

    # Burun ve ağız
    d.polygon([p(482, 690), p(542, 690), p(512, 724)], fill=(232, 112, 126))
    w = 9 * SS
    d.arc(box(482, 730, 30, 26), start=20, end=160, fill=dark, width=w)
    d.arc(box(542, 730, 30, 26), start=20, end=160, fill=dark, width=w)
    d.line([p(512, 722), p(512, 748)], fill=dark, width=w)

    # Bıyıklar
    for side in (-1, 1):
        for dy, tilt in ((-12, -26), (18, 6)):
            d.line([p(512 + side * 170, 712 + dy), p(512 + side * 330, 712 + dy + tilt)], fill=(255, 250, 244), width=7 * SS)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT)
    print(f"✓ {OUT.relative_to(ROOT)}")
    LOGO.mkdir(exist_ok=True)
    img.resize((360, 360), Image.LANCZOS).save(LOGO / "AppLogo.png")
    (LOGO / "Contents.json").write_text(
        '{\n  "images" : [\n    {\n      "filename" : "AppLogo.png",\n      "idiom" : "universal"\n    }\n  ],\n'
        '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
    )
    print(f"✓ {LOGO.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
