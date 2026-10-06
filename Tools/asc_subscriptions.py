#!/usr/bin/env python3
"""Abonelik grubunun ve iki aboneliğin 8 dildeki adlarını/açıklamalarını App Store Connect'e yazar.

Kullanım (iş akışında):  ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… python3 Tools/asc_subscriptions.py

Fiyatlar, inceleme görseli ve notu App Store Connect'te elle girilir; bu araç yalnızca metinleri
oluşturur ya da günceller (tekrar çalıştırmak güvenlidir). Gerekenler: PyJWT, cryptography.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

BUNDLE_ID = "com.catgridcollection.nonogram"
API = "https://api.appstoreconnect.apple.com/v1"
GROUP_NAME = "Catgrid Premium"

# Apple sınırları: ad en çok 35, açıklama en çok 55 karakter
SUBSCRIPTIONS = {
    "com.catgridcollection.nonogram.premium.yearly": {
        "en-US": ("Premium Yearly", "No ads, golden puzzles and Golden Cards for a year."),
        "tr": ("Yıllık Premium", "Bir yıl boyunca reklamsız, altın bulmaca ve kartlar."),
        "ja": ("Premium 年額", "広告なし、ゴールデンパズルとゴールデンカードを1年間お楽しみいただけます。"),
        "de-DE": ("Premium Jährlich", "Ein Jahr ohne Werbung, mit goldenen Rätseln und Karten."),
        "fr-FR": ("Premium annuel", "Un an sans pub, avec grilles et cartes dorées."),
        "es-ES": ("Premium anual", "Un año sin anuncios, con puzles y cartas dorados."),
        "pt-BR": ("Premium Anual", "Um ano sem anúncios, com desafios e cartas douradas."),
        "ko": ("프리미엄 연간", "1년 내내 광고 없이 골든 퍼즐과 골든 카드를 즐겨요."),
    },
    "com.catgridcollection.nonogram.premium.monthly": {
        "en-US": ("Premium Monthly", "No ads, golden puzzles and Golden Cards, every month."),
        "tr": ("Aylık Premium", "Reklamsız, altın bulmaca ve kartlar; her ay yenilenir."),
        "ja": ("Premium 月額", "広告なし、ゴールデンパズルとゴールデンカード。毎月自動更新されます。"),
        "de-DE": ("Premium Monatlich", "Monatlich: keine Werbung, goldene Rätsel und Karten."),
        "fr-FR": ("Premium mensuel", "Sans pub, avec grilles et cartes dorées, chaque mois."),
        "es-ES": ("Premium mensual", "Sin anuncios, con puzles y cartas dorados, cada mes."),
        "pt-BR": ("Premium Mensal", "Sem anúncios, com desafios e cartas douradas, todo mês."),
        "ko": ("프리미엄 월간", "광고 없이 골든 퍼즐과 골든 카드를 즐겨요. 매월 갱신돼요."),
    },
}


def check_limits():
    for product, locales in SUBSCRIPTIONS.items():
        for locale, (name, description) in locales.items():
            assert len(name) <= 35 and len(description) <= 55, (product, locale, len(name), len(description))


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        os.environ["ASC_PRIVATE_KEY"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})


def call(method, path, body=None):
    request = urllib.request.Request(
        path if path.startswith("http") else API + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} → {error.code}\n{error.read().decode()}")


def upsert(kind, existing, locale, attributes, parent_type, parent_id):
    current = existing.get(locale)
    if current:
        if all(current["attributes"].get(k) == v for k, v in attributes.items()):
            return "aynı"
        call("PATCH", f"/{kind}/{current['id']}",
             {"data": {"type": kind, "id": current["id"], "attributes": attributes}})
        return "güncellendi"
    relation = "subscriptionGroup" if parent_type == "subscriptionGroups" else "subscription"
    call("POST", f"/{kind}", {"data": {
        "type": kind, "attributes": {**attributes, "locale": locale},
        "relationships": {relation: {"data": {"type": parent_type, "id": parent_id}}}}})
    return "eklendi"


def main():
    check_limits()
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        sys.exit(f"{BUNDLE_ID} bulunamadı")
    app_id = apps[0]["id"]

    groups = call("GET", f"/apps/{app_id}/subscriptionGroups?limit=50")["data"]
    if not groups:
        sys.exit("Abonelik grubu yok: önce App Store Connect'te 'Premium' grubunu oluşturun")
    found = set()
    for group in groups:
        group_id = group["id"]
        print(f"Grup: {group['attributes']['referenceName']}")
        locs = call("GET", f"/subscriptionGroups/{group_id}/subscriptionGroupLocalizations?limit=50")["data"]
        existing = {loc["attributes"]["locale"]: loc for loc in locs}
        for locale in SUBSCRIPTIONS[next(iter(SUBSCRIPTIONS))]:
            result = upsert("subscriptionGroupLocalizations", existing, locale, {"name": GROUP_NAME},
                            "subscriptionGroups", group_id)
            print(f"  grup [{locale}] {result}")

        subs = call("GET", f"/subscriptionGroups/{group_id}/subscriptions?limit=50")["data"]
        for sub in subs:
            product = sub["attributes"]["productId"]
            texts = SUBSCRIPTIONS.get(product)
            if not texts:
                print(f"  {product}: tanımsız, atlandı")
                continue
            found.add(product)
            locs = call("GET", f"/subscriptions/{sub['id']}/subscriptionLocalizations?limit=50")["data"]
            existing = {loc["attributes"]["locale"]: loc for loc in locs}
            for locale, (name, description) in texts.items():
                result = upsert("subscriptionLocalizations", existing, locale,
                                {"name": name, "description": description}, "subscriptions", sub["id"])
                print(f"  {product} [{locale}] {result}")

    missing = set(SUBSCRIPTIONS) - found
    if missing:
        sys.exit(f"App Store Connect'te bulunamayan ürünler: {sorted(missing)}")
    print("Tamam")


if __name__ == "__main__":
    main()
