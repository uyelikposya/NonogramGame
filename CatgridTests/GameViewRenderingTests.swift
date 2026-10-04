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

    private func spin(_ seconds: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
