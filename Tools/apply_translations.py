#!/usr/bin/env python3
"""Tools/i18n/<dil>.json çevirilerini uygulamaya işler (İngilizce ana dil, Türkçe elle).

Kullanım:  python3 Tools/apply_translations.py

- Localizable.xcstrings ve InfoPlist.xcstrings: her anahtara dilin karşılığı (çoğullar dahil)
- Puzzles/*.json: {"en", "tr"} biçimindeki tüm içerik metinlerine (tür adları, kartlar,
  bulmaca adları) dilin karşılığı; İngilizce metin anahtar olarak kullanılır
- Catgrid.storekit: simülatörde test için ürün adları/açıklamaları

Eksik çeviri hata sayılır. Yeni bir metin eklenince Tools/i18n/source.json yeniden üretilip
her dil dosyasına karşılığı eklenmelidir (bkz. `--source`).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "Tools/i18n"
RES = ROOT / "Catgrid/Resources"
LANGS = ["ja", "de", "fr", "es", "pt-BR", "ko"]
STOREKIT_LOCALE = {"ja": "ja", "de": "de", "fr": "fr", "es": "es", "pt-BR": "pt_BR", "ko": "ko"}


def load_lang(lang):
    return json.loads((I18N / f"{lang}.json").read_text())


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def apply_catalog(path, section, translations, errors):
    data = json.loads(path.read_text())
    for key, entry in data["strings"].items():
        locs = entry.setdefault("localizations", {})
        is_plural = "variations" in locs.get("en", {})
        for lang, tr in translations.items():
            value = tr[section].get(key)
            if value is None:
                errors.append(f"{path.name} [{lang}] çeviri yok: {key!r}")
                continue
            if isinstance(value, dict):
                forms = {form: unit(text) for form, text in value.items()}
                locs[lang] = {"variations": {"plural": forms}} if is_plural or len(forms) > 1 else forms["other"]
            else:
                locs[lang] = unit(value)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def apply_content(translations, errors, root=RES / "Puzzles"):
    def walk(node):
        if isinstance(node, dict):
            if {"en", "tr"} <= node.keys() and all(isinstance(v, str) for v in node.values()):
                for lang, tr in translations.items():
                    value = tr["content"].get(node["en"])
                    if value is None:
                        errors.append(f"içerik [{lang}] çeviri yok: {node['en']!r}")
                    else:
                        node[lang] = value
                return
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    for path in sorted(root.glob("*.json")):
        data = json.loads(path.read_text())
        walk(data)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def apply_storekit(translations, errors):
    path = RES / "Catgrid.storekit"
    data = json.loads(path.read_text())
    for group in data["subscriptionGroups"]:
        names = {loc["locale"] for loc in group["localizations"]}
        for lang in translations:
            if STOREKIT_LOCALE[lang] not in names:
                group["localizations"].append({"description": "", "displayName": "Catgrid Premium", "locale": STOREKIT_LOCALE[lang]})
        for product in group["subscriptions"]:
            english = next(loc for loc in product["localizations"] if loc["locale"] == "en_US")
            product["localizations"] = [loc for loc in product["localizations"]
                                        if loc["locale"] not in STOREKIT_LOCALE.values()]
            for lang, tr in translations.items():
                name = tr["storekit"].get(english["displayName"])
                description = tr["storekit"].get(english["description"])
                if name is None or description is None:
                    errors.append(f"storekit [{lang}] çeviri yok: {english['displayName']!r}")
                    continue
                product["localizations"].append({"description": description, "displayName": name, "locale": STOREKIT_LOCALE[lang]})
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")


def main(content_only=False):
    translations = {lang: load_lang(lang) for lang in LANGS}
    errors = []
    apply_content(translations, errors)
    if not content_only:
        apply_catalog(RES / "Localizable.xcstrings", "ui", translations, errors)
        apply_catalog(RES / "InfoPlist.xcstrings", "infoplist", translations, errors)
        apply_storekit(translations, errors)
    for error in errors:
        print(f"✗ {error}")
    print(f"{len(LANGS)} dil işlendi, {len(errors)} hata")
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main(content_only="--content-only" in sys.argv)
