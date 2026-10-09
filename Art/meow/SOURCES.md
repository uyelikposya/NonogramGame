# Kedi miyavı ses kaynakları (Wikimedia Commons, yalnızca PD / CC0)

**Durum: Henüz hiçbir ses dosyası indirilemedi.**

## Ne denendi

- Wikimedia Commons API (`https://commons.wikimedia.org/w/api.php`) ile
  `File:` ad alanında (srnamespace=6) ses dosyası araması:
  - `meow`
  - `cat meowing`
  - `Felis catus vocalization`
  - `cat meow`
- Planlanan: `Category:Audio files of cats` ve alt kategorilerinin taranması,
  ardından her aday için `imageinfo` (`iiprop=url|extmetadata|mime|size`) ile
  lisans kontrolü (yalnızca Public Domain / CC0 kabul; CC-BY, CC-BY-SA vb. hariç).

## Neden hiçbir dosya eklenmedi

Bu çalışma ortamının ağ (egress) politikası `commons.wikimedia.org` ve
`upload.wikimedia.org` adreslerine erişimi engelledi (proxy CONNECT isteğine
HTTP 403 döndü). Bu yüzden arama sonuçları alınamadı, lisanslar
doğrulanamadı ve hiçbir ses dosyası indirilemedi. Lisansı doğrulanmamış
hiçbir dosya eklenmedi.

## Sonraki adım

Ortam ayarlarında (Network access → Allowed domains) `commons.wikimedia.org`
ve `upload.wikimedia.org` izin verildikten sonra aynı görev tekrar
çalıştırılabilir. Eklenecek her dosya için bu tabloya şu bilgiler yazılacak:

| Yerel dosya | Commons sayfası | Yazar | Lisans | Süre |
|---|---|---|---|---|
| — | — | — | — | — |
