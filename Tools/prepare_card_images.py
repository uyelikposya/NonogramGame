#!/usr/bin/env python3
"""Tür kartı görsellerini uygulamaya hazırlar.

Kullanım:  python3 Tools/prepare_card_images.py <tür-id> <normal.jpg|png> [<altın.jpg|png>]
Örnek:     python3 Tools/prepare_card_images.py siamese siyam.jpg siyam_tacli.jpg

- 1024×1024'e küçültür (kare değilse beyazla kareye tamamlar)
- Kenarlara bağlı açık, renksiz zemini saf beyaza çevirir (kedinin krem tüyüne dokunmaz)
- Assets.xcassets içine card-<tür>.imageset ve card-<tür>-golden.imageset olarak yazar
Pillow ve numpy gerekir.
"""
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ASSETS = Path(__file__).resolve().parent.parent / "Catgrid/Resources/Assets.xcassets"
SIZE = 1024


def whiten_background(im):
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    low, high = a.min(2), a.max(2)
    candidate = (low > 200) & (high - low < 14)
    mask = np.zeros((h, w), bool)
    queue = deque([(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)]
                  + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)])
    while queue:
        y, x = queue.popleft()
        if mask[y, x] or not candidate[y, x]:
            continue
        mask[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx]:
                queue.append((ny, nx))
    soft = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)),
                      dtype=np.float32)[..., None] / 255
    return Image.fromarray((a * (1 - soft) + 255 * soft).clip(0, 255).astype(np.uint8)), mask.mean()


def prepare(source, name):
    im = Image.open(source)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        flat = Image.new("RGBA", im.size, (255, 255, 255, 255))
        flat.alpha_composite(im)
        im = flat
    im = im.convert("RGB")
    side = max(im.size)
    square = Image.new("RGB", (side, side), (255, 255, 255))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    square = square.resize((SIZE, SIZE), Image.LANCZOS)
    clean, ratio = whiten_background(square)
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(exist_ok=True)
    clean.save(folder / f"{name}.jpg", quality=88)
    (folder / "Contents.json").write_text(json.dumps(
        {"images": [{"filename": f"{name}.jpg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
        indent=2) + "\n")
    print(f"{name}: zemin %{round(ratio * 100)}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    breed = sys.argv[1]
    prepare(sys.argv[2], f"card-{breed}")
    if len(sys.argv) > 3:
        prepare(sys.argv[3], f"card-{breed}-golden")
