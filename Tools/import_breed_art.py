#!/usr/bin/env python3
"""Kullanıcının hazırladığı tür görsellerini uygulamaya alır.

Kaynak: "Kart Gorsel/Katalog Size Min/<Tür> Katalog.jpeg" (2816x1536 manzara) ve
        "Kart Gorsel/Portre size min/<Tür> Portre.jpeg" (2048x2048, beyaz zemin).
Çıktı:  Assets.xcassets/Cards/card-<id>.imageset   (1350x1000, kartın büyük resim alanı)
        Assets.xcassets/Portraits/portrait-<id>.imageset (512x512, yuvarlak rozetler ve Kedi Bulmaca)

Manzaralar kartın oranına (1.35:1) kırpılırken kedi dışarıda kalmasın diye her görselin
yatay merkezi elle belirlendi (CROP_CENTER, 0…1).
"""
import json
import unicodedata
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Kart Gorsel"
ASSETS = ROOT / "Catgrid/Resources/Assets.xcassets"

NAMES = {
    "ankara kedisi": "turkish-angora", "bengal": "bengal", "birman": "birman", "bombay": "bombay",
    "british shorthair": "british-shorthair", "burma": "burmese", "chartreux": "chartreux",
    "devon rex": "devon-rex", "exotic shorthair": "exotic-shorthair", "habeş": "abyssinian",
    "himalaya": "himalayan", "iran kedisi": "persian", "i̇ran kedisi": "persian", "japon bobtail": "japanese-bobtail",
    "japonbobtail": "japanese-bobtail", "maine coon": "maine-coon", "manx": "manx", "mısır mau": "egyptian-mau",
    "norveç orman kedisi": "norwegian-forest", "oriental shorthair": "oriental-shorthair",
    "ragdoll": "ragdoll", "rus mavisi": "russian-blue", "scottish fold": "scottish-fold",
    "sfenks": "sphynx", "sibirya": "siberian", "siyam": "siamese", "somali": "somali",
    "van kedisi": "turkish-van",
}

CROP_CENTER = {
    "turkish-angora": 0.55, "bengal": 0.45, "birman": 0.632, "bombay": 0.6, "british-shorthair": 0.55,
    "burmese": 0.632, "chartreux": 0.5, "devon-rex": 0.632, "exotic-shorthair": 0.6, "abyssinian": 0.55,
    "himalayan": 0.5, "persian": 0.632, "japanese-bobtail": 0.45, "maine-coon": 0.45, "manx": 0.5,
    "egyptian-mau": 0.45, "norwegian-forest": 0.4, "oriental-shorthair": 0.57, "ragdoll": 0.48,
    "russian-blue": 0.6, "scottish-fold": 0.55, "sphynx": 0.48, "siberian": 0.45, "siamese": 0.4,
    "somali": 0.6, "turkish-van": 0.48,
}


def breed_id(path: Path, suffix: str) -> str:
    name = unicodedata.normalize("NFC", path.stem).lower().replace(suffix, "").strip()
    if name not in NAMES:
        raise SystemExit(f"Tanınmayan tür adı: {path.name}")
    return NAMES[name]


def write_imageset(folder: Path, name: str, image: Image.Image, quality: int):
    imageset = folder / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    image.save(imageset / f"{name}.jpg", "JPEG", quality=quality, optimize=True, progressive=True)
    contents = {"images": [{"filename": f"{name}.jpg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def folder(name: str) -> Path:
    path = ASSETS / name
    path.mkdir(exist_ok=True)
    (path / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    return path


def main():
    cards = folder("Cards")
    portraits = folder("Portraits")
    seen_cards, seen_portraits = set(), set()
    for path in sorted((SOURCE / "Katalog Size Min").glob("*.jp*g")):
        breed = breed_id(path, "katalog")
        image = Image.open(path).convert("RGB")
        width, height = image.size
        crop_width = round(height * 1.35)
        center = CROP_CENTER[breed] * width
        left = int(min(max(center - crop_width / 2, 0), width - crop_width))
        card = image.crop((left, 0, left + crop_width, height)).resize((1350, 1000), Image.LANCZOS)
        write_imageset(cards, f"card-{breed}", card, 80)
        seen_cards.add(breed)
    for path in sorted((SOURCE / "Portre size min").glob("*.jp*g")):
        breed = breed_id(path, "portre")
        image = Image.open(path).convert("RGB").resize((512, 512), Image.LANCZOS)
        write_imageset(portraits, f"portrait-{breed}", image, 82)
        seen_portraits.add(breed)
    print(f"{len(seen_cards)} kart, {len(seen_portraits)} portre")
    missing = set(NAMES.values()) - seen_cards, set(NAMES.values()) - seen_portraits
    if any(missing):
        print("Eksik:", missing)


if __name__ == "__main__":
    main()
