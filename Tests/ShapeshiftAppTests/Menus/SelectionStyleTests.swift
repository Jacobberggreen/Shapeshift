import XCTest
import AppKit
@testable import ShapeshiftApp

final class SelectionStyleTests: XCTestCase {
    private let blue = NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)

    func testHexRoundTripAndRejectsGarbage() {
        XCTAssertEqual(SelectionStyle.hex(of: SelectionStyle.parseHex("#ff8800")!), "#FF8800")
        XCTAssertEqual(SelectionStyle.hex(of: SelectionStyle.parseHex("00FF00")!), "#00FF00")
        XCTAssertNil(SelectionStyle.parseHex("#12345"))
        XCTAssertNil(SelectionStyle.parseHex("zzzzzz"))
    }

    func testLighterIsBrighterAndDarkerIsDarkerThanAccent() {
        let accent = SelectionStyle.luminance(of: NSColor(SelectionStyle.resolve(mode: .accent, customHex: "", accent: blue).fill))
        let lighter = SelectionStyle.luminance(of: NSColor(SelectionStyle.resolve(mode: .lighter, customHex: "", accent: blue).fill))
        let darker = SelectionStyle.luminance(of: NSColor(SelectionStyle.resolve(mode: .darker, customHex: "", accent: blue).fill))
        XCTAssertGreaterThan(lighter, accent)
        XCTAssertLessThan(darker, accent)
    }

    func testLighterAndDarkerAreNeutralGreysNotPureWhiteOrBlack() {
        for mode in [SelectionColorMode.lighter, .darker] {
            let color = NSColor(SelectionStyle.resolve(mode: mode, customHex: "", accent: blue).fill).usingColorSpace(.sRGB)!
            XCTAssertLessThan(abs(color.redComponent - color.blueComponent), 0.05, "\(mode) should be (nearly) grey")
            let l = SelectionStyle.luminance(of: color)
            XCTAssertTrue(l > 0.1 && l < 0.9, "\(mode) must not be pure black or white")
        }
        XCTAssertFalse(SelectionStyle.resolve(mode: .lighter, customHex: "", accent: blue).labelIsLight)
        XCTAssertTrue(SelectionStyle.resolve(mode: .darker, customHex: "", accent: blue).labelIsLight)
    }

    func testLabelContrastFollowsFill() {
        XCTAssertTrue(SelectionStyle.resolve(mode: .custom, customHex: "#101010").labelIsLight)
        XCTAssertFalse(SelectionStyle.resolve(mode: .custom, customHex: "#F5F5A0").labelIsLight)
        XCTAssertTrue(SelectionStyle.resolve(mode: .accent, customHex: "", accent: blue).labelIsLight)
    }

    func testBadCustomHexFallsBackToDefault() {
        let style = SelectionStyle.resolve(mode: .custom, customHex: "nope")
        XCTAssertEqual(SelectionStyle.hex(of: NSColor(style.fill)), SettingsStore.defaultSelectionHex)
    }
}
