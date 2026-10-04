# Purrfect Nonogram (geçici isim)

Kedi temalı, klasik kurallı iOS Nonogram (Picross) bulmaca oyunu. SwiftUI, iOS 17+, MVVM.

## Kurulum

**Gereksinimler:** macOS 13 Ventura+, **Xcode 15.2** (Swift 5.9, iOS 17.2 SDK). Testler XCTest kullanır.
Kod Xcode 15.2 ile uyumlu tutulur; her push'ta GitHub Actions aynı sürümle derler ve testleri
iOS 17.2 simülatöründe çalıştırır (`.github/workflows/ci.yml`).

Xcode projesi [XcodeGen](https://github.com/yonaskolb/XcodeGen) ile `project.yml`'den üretilir.

```bash
brew install xcodegen
xcodegen generate
open PurrfectNonogram.xcodeproj
```

Testler:

```bash
# Oyun motoru (Xcode projesi gerekmez, macOS'ta çalışır)
cd Packages/NonogramKit && swift test

# Uygulama + paketlenmiş içerik doğrulama
xcodebuild test -scheme PurrfectNonogram -destination 'platform=iOS Simulator,name=iPhone 15'

# Bulmaca içeriği (yalnızca Python 3)
python3 Tools/validate_puzzles.py
```

## Mimari

İki katman:

- **NonogramKit** (yerel Swift Package): yalnızca Foundation. Bulmaca modeli, ipucu hesabı, çözücü,
  oyun kuralları, katalog yükleme, kilit sistemi. UI'dan bağımsız, saf değer tipleri, tamamen test edilebilir.
- **Uygulama**: SwiftUI View + `@Observable` ViewModel'ler ve servisler (kalıcılık, reklam, tema).

```
NonogramGame/
├── project.yml
├── Packages/NonogramKit/
│   ├── Sources/NonogramKit/
│   │   ├── Model/          Matrix, GridPosition, CellState, Puzzle, GameRules, LocalizedText, RGBColor
│   │   ├── Engine/         LineClue, LineSolver, PuzzleSolver, NonogramGame (+ GameSnapshot)
│   │   ├── Content/        LevelCatalog, Chapter, CatalogLoader (JSON → katalog)
│   │   └── Progression/    Progression (kilit kuralları), PuzzleCompletion
│   └── Tests/NonogramKitTests/
├── PurrfectNonogram/
│   ├── App/                PurrfectNonogramApp, AppModel, Router (rotalar), RootView
│   ├── Core/
│   │   ├── Theme/          ThemePalette (4 palet × açık/koyu), AppTheme tokenları, ThemeManager, modifier'lar
│   │   └── Components/     Buton stilleri, ProgressBar, ArtworkThumbnail
│   ├── Features/
│   │   ├── Home/           Ana ekran: genel ilerleme, "Devam Et" kartı
│   │   ├── Levels/         Tür kartları (ChaptersView), 30 bulmacalık ızgara (ChapterView)
│   │   ├── Game/           GameView, BoardView (Canvas), GameViewModel
│   │   ├── Tutorial/       LessonBanner + ders metinleri
│   │   └── Settings/       Palet seçici, görünüm, titreşim, dil
│   ├── Services/           (Aşama 3-4) Persistence/ (SwiftData), Ads/ (AdMob)
│   └── Resources/
│       ├── Puzzles/        catalog.json + bölüm başına bir JSON
│       ├── Localizable.xcstrings, InfoPlist.xcstrings   (EN varsayılan, TR)
│       └── Assets.xcassets
├── PurrfectNonogramTests/  ViewModel testleri + paketlenmiş içerik doğrulama
└── Tools/validate_puzzles.py
```

### Neden bu teknolojiler

| Konu | Seçim | Gerekçe |
|---|---|---|
| Bulmaca içeriği | Paketlenmiş **JSON** (salt okunur) | 460 bulmaca ~150 KB; git'te diff'lenebilir, Xcode'suz doğrulanabilir, uygulama güncellemesiyle değişir |
| İlerleme / yarım oyun | **SwiftData** (Aşama 3) | iOS 17+ ile yerleşik; tamamlanma, en iyi süre, yarım kalan tahta (`GameSnapshot`) |
| Basit ayarlar | `@AppStorage` | Tema paleti, ses, reklam sayacı |
| Yerelleştirme | **String Catalog** (`.xcstrings`) | `Localizable.strings`'in Xcode 15+ halefi; derlemede `.strings`'e dönüşür, eksik çevirileri gösterir. İçerik adları JSON'da `{ "en", "tr" }` |
| Reklam | Google Mobile Ads SDK (SPM) + UMP onayı | Aşama 4 |

## Tema sistemi

View'lar ham renk kullanmaz; `@Environment(\.appTheme)` üzerinden anlamsal tokenları okur
(`background`, `surface`, `accent`, `cellFilled`, `cellCross`, `gridLineMajor`, `highlight`, `mistake`...).
`RootView`, seçili `ThemePalette` ile pencerenin renk şemasından `AppTheme` üretip enjekte eder.
Yeni palet eklemek: `ThemePalette`'e bir case ve iki `ThemeSpec` (açık/koyu) eklemek yeterli.

## Bulmaca veri modeli

**`catalog.json`**: bölüm sırası ve varsayılan kurallar.

```json
{
  "schemaVersion": 1,
  "defaultRules": { "checksMoves": true, "mistakeLimit": 3, "timeLimitSeconds": null, "autoCrossCompletedLines": true },
  "chapters": [
    { "id": "tutorial", "kind": "tutorial", "title": { "en": "Kitten School", "tr": "Yavru Okulu" },
      "accentColor": "#F4A6A0", "file": "tutorial", "expectedPuzzleCount": 10 },
    { "id": "siamese", "kind": "breed", "title": { "en": "Siamese", "tr": "Siyam" },
      "accentColor": "#C9A27E", "file": "chapter_01_siamese", "expectedPuzzleCount": 30 }
  ]
}
```

**Bölüm dosyası** (`chapter_01_siamese.json`): çözüm renkli piksel görsel olarak tutulur.

```json
{
  "schemaVersion": 1,
  "chapterID": "siamese",
  "puzzles": [
    {
      "id": "siamese-001",
      "title": { "en": "Siamese Face", "tr": "Siyam Yüzü" },
      "palette": { "a": "#4A3B35", "b": "#F2E3CF" },
      "pixels": ["a...a", "aaaaa", "b.b.b", "bbbbb", ".bab."],
      "rules": { "mistakeLimit": 3, "timeLimitSeconds": 300 },
      "lesson": null
    }
  ]
}
```

- `.` boş kare; diğer her karakter `palette`teki bir renk ve **dolu** kare.
- İpuçları saklanmaz, yüklemede `pixels`'tan hesaplanır → veri ile ipucu asla çelişmez.
- Çözüm bitince tahta `palette` renkleriyle "kedi resmine" dönüşür.
- `rules` isteğe bağlı: süreli/sınırsız bölümler için katalog varsayılanını ezer.
- `lesson` yalnızca eğitim bölümlerinde: arayüz o dersin anlatımını gösterir.
- Kimlikler (`siamese-001`) kalıcıdır; ilerleme kaydı bunlara bağlanır, sonradan değiştirilmemeli.

**Kalite kuralı:** her bulmaca tahmin yapmadan, yalnızca satır mantığıyla çözülebilmeli
(bu, çözümün benzersiz olduğunu da garanti eder). `Tools/validate_puzzles.py` ve
`ContentValidationTests` bunu her bulmaca için kontrol eder.

## Zorluk eğrisi (öneri)

| # | Bölüm | Boyut | Kural |
|---|---|---|---|
| 0 | Yavru Okulu (10) | 5×5 → 8×8 | Hata sınırı yok, ders balonları |
| 1 | Siyam | 5×5 | 3 can |
| 2 | British Shorthair | 5×5–8×8 | 3 can |
| 3 | Scottish Fold | 8×8 | 3 can |
| 4 | İran Kedisi | 8×8–10×10 | 3 can |
| 5 | Ragdoll | 10×10 | 3 can |
| 6 | Rus Mavisi | 10×10 | 3 can |
| 7 | Habeş Kedisi | 10×10–12×12 | 3 can |
| 8 | Birman | 12×12 | 3 can |
| 9 | Bengal | 12×12–15×15 | 3 can |
| 10 | Sfenks | 15×15 | 3 can |
| 11 | Ankara Kedisi | 15×15 | 3 can |
| 12 | Norveç Orman Kedisi | 15×15–15×20 | 3 can |
| 13 | Van Kedisi | 15×20 | 3 can |
| 14 | Maine Coon | 20×20 | 3 can |
| 15 | Egzotik Kısa Tüylü | 20×20 | 3 can, bölüm sonu süreli bonuslar |

Her türün 30. bulmacası o türün büyük portresi olabilir (bölüm finali).

## Yol haritası

- [x] **Aşama 1 — Core Engine ve veri modeli**: NonogramKit, JSON şeması, çözücü/doğrulayıcı,
      kilit sistemi, örnek içerik (10 eğitim + 3 Siyam), prototip oyun ekranı, testler
- [x] **Aşama 2 — UI/UX ve temalar**: 4 palet (Pastel, Gece Mavisi, Kahve Tonları, Matcha) × açık/koyu,
      ana ekran, tür kartları ve bulmaca ızgarası, temalı tahta (satır/sütun vurgusu, hata yanıp sönmesi,
      çözümde kedi resmi animasyonu), eğitim balonları, sonuç kartları, ayarlar, titreşim, EN/TR metinler
- [ ] **Aşama 3 — Kalıcılık**: SwiftData (`PuzzleRecord`: tamamlanma, en iyi süre, `GameSnapshot`),
      yarım oyuna devam, istatistikler
- [ ] **Aşama 4 — Reklam ve yerelleştirme**: AdMob SPM, UMP/GDPR-KVKK onayı, ATT, `AdService` protokolü,
      her 2 tamamlanan bulmacada bir geçiş reklamı, isteğe bağlı ödüllü reklam (ekstra can / ipucu),
      tüm metinlerin TR çevirisi
- [ ] **Aşama 5 — İçerik üretimi**: 450 tür bulmacası; PNG → JSON dönüştürücü + doğrulayıcı
- [ ] **Aşama 6 — Cila ve yayın**: ses/haptik, erişilebilirlik (VoiceOver, Dynamic Type), performans,
      App Store materyalleri
