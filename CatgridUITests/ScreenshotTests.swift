import XCTest

/// App Store ekran görüntüleri. Yalnızca "Ekran görüntüleri" iş akışında çalışır
/// (`CATGRID_SCREENSHOTS=1`); normal CI'da atlanır.
///
/// Uygulama `-screenshots` ile örnek ilerlemeyle açılır, 5 ekran sırayla gezilir ve her biri
/// test sonucuna `<dil>_<sıra>_<ad>` adlı ek olarak kaydedilir.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureStoreScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CATGRID_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Yalnızca ekran görüntüsü iş akışında çalışır")
        }
        let language = environment["CATGRID_LANG"] ?? "en"
        let locale = environment["CATGRID_LOCALE"] ?? "en_US"

        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-screenshots", "-disableAds"]
        app.launch()

        // 1. Ana sayfa: logo, devam kartı, koleksiyon rafı
        let start = app.buttons["home.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        settle()
        capture("01_home")

        // 2. Oyun: yarısı çözülmüş zor bölüm, yardımcı kedi
        // İlk açılışta soğuk simülatör yavaş olabilir: bekle, dokunuş kaçtıysa bir kez daha dokun
        start.tap()
        let board = app.descendants(matching: .any)["game.board"]
        if !board.waitForExistence(timeout: 20), start.exists {
            start.tap()
        }
        XCTAssertTrue(board.waitForExistence(timeout: 30))
        settle(2.5)
        capture("02_game")
        goBack(app)

        // 3. Bir türün bölümleri: çözülen bulmacaların resimleri
        let levels = app.buttons["home.levels"]
        XCTAssertTrue(levels.waitForExistence(timeout: 20))
        levels.tap()
        let chapter = app.buttons["chapter.siamese"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 20))
        chapter.tap()
        settle()
        capture("03_chapter")
        goBack(app)
        goBack(app)

        // 4. Kart koleksiyonu
        let collection = app.buttons["home.collection"]
        XCTAssertTrue(collection.waitForExistence(timeout: 20))
        collection.tap()
        settle()
        capture("04_collection")

        // 5. Altın Kart
        let golden = app.buttons["collection.card.siamese#golden"]
        XCTAssertTrue(golden.waitForExistence(timeout: 20))
        golden.tap()
        settle(2)
        capture("05_golden_card")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(ProcessInfo.processInfo.environment["CATGRID_LANG"] ?? "en")_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Animasyonların bitmesi için kısa bekleme.
    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
        settle(0.6)
    }
}
