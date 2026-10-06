#!/usr/bin/env python3
"""Ham App Store ekran görüntülerini başlıklı mağaza görsellerine dönüştürür.

Kullanım:  python3 Tools/frame_screenshots.py <fastlane/screenshots klasörü>

Her <dil>/<sıra>_<ad>.png için: sıcak renkli zemin, üstte o dilde kısa bir başlık,
altında yuvarlatılmış köşeli ve gölgeli ekran görüntüsü. Görsel aynı boyutta kalır
(6,9" için 1320×2868) ve dosyanın üzerine yazılır. Pillow gerekir.

Yazı tipleri macOS'tan alınır (SF Pro Rounded, Hiragino, Apple SD Gothic Neo); başka
sistemde denemek için CATGRID_FONT=<yol> ile tek bir yazı tipi verilebilir.
"""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTIONS = {
    "en-US": ["Solve puzzles,\ncollect\nCat Fact Cards", "Picture logic\npuzzles", "400 puzzles across\n25 cat breeds",
              "A fact card for\nevery cat breed", "Premium: extra levels,\nGolden Fact Cards\nand no ads"],
    "tr": ["Bulmacaları çöz,\nKedi Bilgi\nKartlarını Topla", "Resimli mantık\nbulmacaları", "25 kedi türüne özel\n400 bulmaca",
           "Her kedi türüne özel\nbilgi kartları", "Premium ile\nekstra bölümler,\naltın bilgi kartı ve\nreklamsız deneyim"],
    "de-DE": ["Rätsel lösen,\nKatzen-Infokarten\nsammeln", "Logikrätsel\nmit Bildern", "400 Rätsel für\n25 Katzenrassen",
              "Infokarten für\njede Katzenrasse", "Premium: Extra-Level,\ngoldene Infokarten\nund keine Werbung"],
    "fr-FR": ["Résolvez les grilles,\ncollectionnez\nles fiches chats", "Grilles logiques\nen images",
              "400 grilles pour\n25 races de chats", "Une fiche pour\nchaque race de chat",
              "Premium : niveaux bonus,\nfiches dorées\net zéro publicité"],
    "es-ES": ["Resuelve puzles,\ncolecciona fichas\nde gatos", "Puzles lógicos\ncon imágenes", "400 puzles para\n25 razas de gatos",
              "Una ficha para\ncada raza de gato", "Premium: niveles extra,\nfichas doradas\ny sin anuncios"],
    "pt-BR": ["Resolva desafios,\ncolecione fichas\nde gatos", "Quebra-cabeças\nlógicos com imagens", "400 desafios para\n25 raças de gatos",
              "Uma ficha para\ncada raça de gato", "Premium: fases extras,\nfichas douradas\ne sem anúncios"],
    "ja": ["パズルを解いて\n猫の図鑑カードを\n集めよう", "イラスト\nロジックパズル", "25の猫種に\n400のパズル",
           "猫種ごとの\n図鑑カード", "Premiumで追加ステージ、\nゴールデンカード、\n広告なし"],
    "ko": ["퍼즐을 풀고\n고양이 정보 카드를\n모아요", "그림 로직\n퍼즐", "25가지 고양이를 위한\n400개의 퍼즐",
           "품종마다 특별한\n정보 카드", "프리미엄: 추가 스테이지,\n골든 정보 카드,\n광고 없는 플레이"],
}

# Uygulamanın renkleri (Theme): sıcak krem zemin, mercan vurgu, koyu kahve yazı
TOP = (255, 226, 214)
BOTTOM = (253, 244, 236)
INK = (74, 59, 53)
ACCENT = (232, 134, 128)

MAC_LATIN = "/System/Library/Fonts/SFNSRounded.ttf"
MAC_FONTS = {
    "ja": ["/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    "ko": ["/System/Library/Fonts/AppleSDGothicNeo.ttc"],
}


def load_font(locale, size):
    override = os.environ.get("CATGRID_FONT")
    if override:
        return ImageFont.truetype(override, size)
    for path in MAC_FONTS.get(locale, []):
        if Path(path).exists():
            return bold_face(path, size)
    font = ImageFont.truetype(MAC_LATIN, size)
    try:
        font.set_variation_by_axes([700])  # wght
    except (OSError, ValueError):
        pass
    return font


def bold_face(path, size):
    """.ttc içinden kalın yüzü seçer (Apple SD Gothic Neo'da Bold, Hiragino W7 zaten kalın)."""
    best = None
    for index in range(20):
        try:
            face = ImageFont.truetype(path, size, index=index)
        except OSError:
            break
        style = face.getname()[1].lower()
        if style in ("bold", "w7"):
            return face
        best = best or face
    return best


def gradient(size):
    width, height = size
    column = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / (height - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize(size)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def frame(shot_path, caption, locale):
    shot = Image.open(shot_path).convert("RGB")
    width, height = shot.size
    canvas = gradient((width, height))
    draw = ImageDraw.Draw(canvas)
    unit = width / 1320

    # Başlık: iki-üç satır, sığmazsa küçülür
    caption_box = (round(70 * unit), round(110 * unit), width - round(70 * unit), round(585 * unit))
    size = round(118 * unit)
    while True:
        font = load_font(locale, size)
        bbox = draw.multiline_textbbox((0, 0), caption, font=font, align="center", spacing=round(size * 0.22))
        fits = bbox[2] - bbox[0] <= caption_box[2] - caption_box[0] and bbox[3] - bbox[1] <= caption_box[3] - caption_box[1]
        if fits or size <= 60:
            break
        size -= 4
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (width - text_w) / 2 - bbox[0]
    y = caption_box[1] + (caption_box[3] - caption_box[1] - text_h) / 2 - bbox[1]
    draw.multiline_text((x, y), caption, font=font, fill=INK, align="center", spacing=round(size * 0.22))

    # Başlığın altında küçük mercan çizgi
    bar_w, bar_h = round(120 * unit), round(14 * unit)
    bar_y = round(y + bbox[3] + 44 * unit)
    draw.rounded_rectangle([(width - bar_w) / 2, bar_y, (width + bar_w) / 2, bar_y + bar_h], radius=bar_h / 2, fill=ACCENT)

    # Ekran görüntüsü: küçültülmüş, yuvarlak köşeli, beyaz kenarlı ve gölgeli
    scale = 0.74
    inner = shot.resize((round(width * scale), round(height * scale)), Image.LANCZOS)
    border = round(14 * unit)
    radius = round(84 * unit)
    framed_size = (inner.width + 2 * border, inner.height + 2 * border)
    left = (width - framed_size[0]) // 2
    top = height - framed_size[1] - round(60 * unit)

    shadow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, top + round(24 * unit), left + framed_size[0], top + framed_size[1] + round(24 * unit)],
        radius=radius + border, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(40 * unit)))
    canvas.paste(Image.new("RGB", (width, height), (120, 80, 60)), (0, 0), shadow)

    canvas.paste(Image.new("RGB", framed_size, (255, 255, 255)), (left, top), rounded_mask(framed_size, radius + border))
    canvas.paste(inner, (left + border, top + border), rounded_mask(inner.size, radius))
    canvas.save(shot_path, "PNG")


def main(root):
    root = Path(root)
    total = 0
    for locale, captions in CAPTIONS.items():
        folder = root / locale
        if not folder.is_dir():
            print(f"{locale}: klasör yok, atlandı")
            continue
        shots = sorted(folder.glob("*.png"))
        if len(shots) != len(captions):
            sys.exit(f"{locale}: {len(shots)} görüntü var, {len(captions)} başlık bekleniyordu")
        for shot, caption in zip(shots, captions):
            frame(shot, caption, locale)
            total += 1
    print(f"{total} görüntü başlıklandı")


if __name__ == "__main__":
    main(sys.argv[1])
