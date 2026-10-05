#!/usr/bin/env python3
"""xcresult'tan çıkarılan ekran görüntüsü eklerini fastlane klasör yapısına taşır.

Kullanım:  python3 Tools/collect_screenshots.py <results klasörü> <hedef klasör>

`xcresulttool export attachments` her dil için bir manifest.json yazar; ekler testte
`<dil>_<sıra>_<ad>` olarak adlandırılır. Çıktı: <hedef>/<App Store dili>/<sıra>_<ad>.png
"""
import json
import re
import shutil
import sys
from pathlib import Path

results, target = Path(sys.argv[1]), Path(sys.argv[2])
total = 0
for folder in sorted(p for p in results.iterdir() if p.is_dir() and not p.name.endswith(".xcresult")):
    locale = folder.name
    manifest = json.loads((folder / "manifest.json").read_text())
    out = target / locale
    out.mkdir(parents=True, exist_ok=True)
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            # "<dil>_01_home_0_<uuid>.png" → "01_home"
            match = re.search(r"_(\d\d_[a-z]+(?:_[a-z]+)*)", name)
            if not match:
                continue
            label = match.group(1)
            shutil.copy(folder / attachment["exportedFileName"], out / f"{label}.png")
            total += 1
    print(f"{locale}: {sorted(p.name for p in out.iterdir())}")
print(f"Toplam {total} ekran görüntüsü")
if total == 0:
    sys.exit(1)
