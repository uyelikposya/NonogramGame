import NonogramKit
import SwiftUI
import XCTest
@testable import Catgrid

/// Tüm koleksiyon kartlarını ve koleksiyon ekranını gerçek bir pencerede, iki dilde çizer.
/// Metin biçimlendirme hataları (ör. yanlış %@ / %lld) çizim sırasında çöker; bu test yakalar.
@MainActor
final class CollectionRenderingTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testEveryBreedCardRendersInBothLanguages() throws {
        let catalog = try CatalogLoader.load(from: .main)
        let breeds = catalog.chapters.filter { $0.card != nil }
        XCTAssertFalse(breeds.isEmpty)

        for language in ["en", "tr"] {
            let cards = ScrollView {
                VStack {
                    ForEach(breeds) { chapter in
                        BreedCardView(chapter: chapter, card: chapter.card!, style: .full)
                        BreedCardView(chapter: chapter, card: chapter.card!, style: .compact)
                        BreedCardBackView(chapter: chapter, card: chapter.card!)
                        FlippableBreedCard(chapter: chapter, card: chapter.card!)
                    }
                }
            }
            .environment(\.locale, Locale(identifier: language))
            .environment(\.appTheme, .default)
            show(cards)
        }
    }

    func testCollectionScreenRendersWithCollectedBreeds() throws {
        let catalog = try CatalogLoader.load(from: .main)
        let model = AppModel(catalog: catalog, progress: .inMemory())
        // İlk iki türün tüm bulmacalarını çözülmüş say
        for chapter in catalog.chapters.filter({ $0.kind == .breed }).prefix(2) {
            for puzzle in chapter.puzzles {
                model.record(PuzzleCompletion(puzzleID: puzzle.id, completedAt: Date(), elapsed: 30, mistakes: 1))
            }
        }
        XCTAssertEqual(model.collectedBreeds.count, 2)

        show(
            NavigationStack { CollectionView() }
                .environment(model)
                .environment(Router())
                .environment(\.appTheme, .default)
        )
        show(
            NavigationStack { HomeView() }
                .environment(model)
                .environment(Router())
                .environment(\.appTheme, .default)
        )
    }

    func testSettingsScreenRenders() {
        let suffix = UUID().uuidString
        show(
            NavigationStack { SettingsView() }
                .environment(AppModel(catalog: try! CatalogLoader.load(from: .main), progress: .inMemory()))
                .environment(Router())
                .environment(ThemeManager(defaults: UserDefaults(suiteName: "settings-theme-\(suffix)")!))
                .environment(AudioManager(defaults: UserDefaults(suiteName: "settings-audio-\(suffix)")!))
                .environment(AdCoordinator(service: NoAdService()))
                .environment(StoreManager(defaults: UserDefaults(suiteName: "settings-store-\(suffix)")!))
                .environment(\.appTheme, .default)
        )
    }

    private func show(_ view: some View) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2400))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        self.window = window
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        window.rootViewController?.view.layoutIfNeeded()
    }
}
