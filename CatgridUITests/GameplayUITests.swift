import XCTest

/// Gerçek dokunma ve sürüklemeyle oyun ekranını dener (birim testlerin yakalayamadığı
/// SwiftUI/gesture çökmeleri için).
final class GameplayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTapAndDragOnBoardDoesNotCrash() {
        let app = XCUIApplication()
        // Reklam SDK'sı ve onay/izleme pencereleri kapalı: yalnızca oyun ekranını dener
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let start = app.buttons["home.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "Ana ekrandaki oyna düğmesi görünmedi")
        start.tap()

        let board = app.descendants(matching: .any)["game.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Tahta görünmedi")

        // Tek tek dokunuşlar
        for (x, y) in [(0.5, 0.5), (0.3, 0.3), (0.7, 0.7), (0.5, 0.5)] {
            board.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        }
        // Sürükleme
        let from = board.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let to = board.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: to)

        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
        XCTAssertTrue(board.exists)
    }
}
