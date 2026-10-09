import NonogramKit
import SwiftUI
import XCTest
@testable import Catgrid

final class CompanionCoatTests: XCTestCase {
    private let cream = RGBColor(red: 0xF2, green: 0xE3, blue: 0xCF)
    private let seal = RGBColor(red: 0x4A, green: 0x3B, blue: 0x35)

    /// Koyu uçlu portre: tüy krem, kulak ve kuyruk koyu.
    func testColorpointPortraitGivesDarkPoints() throws {
        let portrait = try XCTUnwrap(Matrix<RGBColor?>([
            [seal, cream, cream, seal],
            [cream, cream, cream, cream],
            [cream, cream, cream, nil],
        ]))
        let coat = try XCTUnwrap(CatCoat(portrait: portrait))
        XCTAssertEqual(coat.fur, Color(cream))
        XCTAssertEqual(coat.points, Color(seal))
    }

    /// Düz renkli koyu kedi: uçlar tüyle aynı, gözler açık renk.
    func testSolidDarkPortraitKeepsEyesVisible() throws {
        let portrait = try XCTUnwrap(Matrix<RGBColor?>([[seal, seal], [seal, nil]]))
        let coat = try XCTUnwrap(CatCoat(portrait: portrait))
        XCTAssertEqual(coat.points, coat.fur)
        XCTAssertNotEqual(coat.eyes, CatCoat.ginger.eyes)
        XCTAssertNil(CatCoat(portrait: try XCTUnwrap(Matrix<RGBColor?>([[nil]]))))
    }
}
