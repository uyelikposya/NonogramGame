import NonogramKit
import SwiftUI
import XCTest
@testable import Catgrid

/// Oyun ekranı gerçek bir pencerede çizilirken dokunma yolunu (dragBegan/Moved/Ended) sürer.
/// SwiftUI'nin gözlem (Observation) güncellemeleri bu sırada gerçekten çalışır; birim testlerin
/// tek başına yakalayamadığı çizim/gözlem çökmeleri için.
@MainActor
final class GameViewRenderingTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testDraggingOnRenderedBoardUpdatesWithoutCrashing() throws {
        let puzzle = Puzzle(id: "render", pattern: [".#.#.", "#####", "#####", ".###.", "..#.."])
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 1, puzzles: [puzzle]),
        ])
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        let model = AppModel(catalog: catalog, progress: .inMemory())
        let audio = AudioManager(defaults: UserDefaults(suiteName: "render-\(UUID().uuidString)")!)

        let root = NavigationStack {
            GameView(viewModel: viewModel)
        }
        .environment(model)
        .environment(Router())
        .environment(audio)
        .environment(AdCoordinator(service: NoAdService()))
        .environment(StoreManager(defaults: UserDefaults(suiteName: "game-store-\(UUID().uuidString)")!))
        .environment(ThemeManager(defaults: UserDefaults(suiteName: "render-theme-\(UUID().uuidString)")!))
        .environment(\.appTheme, .default)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        self.window = window
        spin()

        // Dokunuşlar ve sürükleme: her adımda SwiftUI'nin yeniden çizmesine izin ver
        let positions = (0..<5).flatMap { row in (0..<5).map { GridPosition(row: row, column: $0) } }
        for position in positions.prefix(8) {
            viewModel.dragBegan(at: position)
            spin()
            viewModel.dragEnded()
            spin()
        }
        viewModel.tool = .cross
        viewModel.dragBegan(at: GridPosition(row: 0, column: 0))
        for column in 1..<5 {
            viewModel.dragMoved(to: GridPosition(row: 0, column: column))
            spin()
        }
        viewModel.dragEnded()
        spin()

        XCTAssertNil(viewModel.activeCell)
        XCTAssertTrue(viewModel.game.board.storage.contains { $0 != .blank })
    }

    /// Tahtanın altındaki kedi kendi döngüsünde dolaşırken oyun oynanabilmeli.
    func testCompanionCatAnimatesAlongsideBoard() throws {
        let puzzle = Puzzle(id: "companion", pattern: ["#####", "#...#", "#...#", "#...#", "#####"])
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 1, puzzles: [puzzle]),
        ])
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        let root = NavigationStack {
            GameView(viewModel: viewModel)
        }
        .environment(AppModel(catalog: catalog, progress: .inMemory()))
        .environment(Router())
        .environment(AudioManager(defaults: UserDefaults(suiteName: "companion-\(UUID().uuidString)")!))
        .environment(AdCoordinator(service: NoAdService()))
        .environment(StoreManager(defaults: UserDefaults(suiteName: "game-store-\(UUID().uuidString)")!))
        .environment(\.appTheme, .default)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        self.window = window
        RunLoop.main.run(until: Date().addingTimeInterval(2))

        // Kedinin önerdiği satır gerçekten ilerletilebilmeli
        let hint = try XCTUnwrap(HintFinder.bestHint(board: viewModel.game.board, puzzle: puzzle))
        XCTAssertEqual(hint.axis, .row)
        for column in 0..<5 {
            viewModel.dragBegan(at: GridPosition(row: hint.index, column: column))
            viewModel.dragEnded()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(viewModel.game.isRowSatisfied(hint.index))
    }

    /// Kullanıcı bildirimi: hata yapıp şekli tamamlayınca sonuç kartındaki "Süre · N hata" metni
    /// biçimlendirilirken çökme. Sonuç kartını gerçekten çizer.
    func testWinningAfterMistakesRendersResultCard() throws {
        let puzzle = Puzzle(id: "render-win", pattern: ["##", "#."])
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "tutorial", kind: .tutorial, title: ["en": "School"], expectedPuzzleCount: 1, puzzles: [puzzle]),
        ])
        let viewModel = GameViewModel(puzzle: puzzle, rules: .relaxed)
        try host(GameView(viewModel: viewModel), catalog: catalog)

        for _ in 0..<3 {   // aynı boş kareye üç kez yanlış dolgu denemesi -> 1 hata (kare kilitlenir)
            viewModel.dragBegan(at: GridPosition(row: 1, column: 1))
            viewModel.dragEnded()
            spin()
        }
        for position in [GridPosition(row: 0, column: 0), GridPosition(row: 0, column: 1), GridPosition(row: 1, column: 0)] {
            viewModel.dragBegan(at: position)
            viewModel.dragEnded()
            spin()
        }
        XCTAssertEqual(viewModel.game.status, .won)
        XCTAssertEqual(viewModel.game.mistakes, 1)

        // Kart göründükten sonra tahtaya tekrar dokunmak (kullanıcının çöktüğü an)
        viewModel.dragBegan(at: GridPosition(row: 1, column: 1))
        spin(0.3)
        viewModel.dragEnded()
        spin(0.3)
    }

    private func host(_ view: GameView, catalog: LevelCatalog) throws {
        let root = NavigationStack { view }
            .environment(AppModel(catalog: catalog, progress: .inMemory()))
            .environment(Router())
            .environment(AudioManager(defaults: UserDefaults(suiteName: "render-\(UUID().uuidString)")!))
            .environment(AdCoordinator(service: NoAdService()))
            .environment(StoreManager(defaults: UserDefaults(suiteName: "game-store-\(UUID().uuidString)")!))
            .environment(ThemeManager(defaults: UserDefaults(suiteName: "render-theme-\(UUID().uuidString)")!))
            .environment(\.appTheme, .default)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        self.window = window
        spin()
    }

    private func spin(_ seconds: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
