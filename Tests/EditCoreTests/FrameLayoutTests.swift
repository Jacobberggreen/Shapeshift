import XCTest
@testable import EditCore

final class FrameLayoutTests: XCTestCase {
    private let size = CGSize(width: 100, height: 60)

    func testDefaultStyleIsIdentityLayout() {
        let l = FrameLayout.compute(imageSize: size, style: FrameStyle(), unit: 1)
        XCTAssertEqual(l.canvas, size)
        XCTAssertEqual(l.card, CGRect(x: 0, y: 0, width: 100, height: 60))
        XCTAssertEqual(l.content, l.card)
        XCTAssertNil(l.titleBar)
        XCTAssertEqual(l.cornerRadius, 0)
    }

    func testMarginAddsToEverySide() {
        var s = FrameStyle(); s.margin = 10
        let l = FrameLayout.compute(imageSize: size, style: s, unit: 1)
        XCTAssertEqual(l.canvas, CGSize(width: 120, height: 80))
        XCTAssertEqual(l.content, CGRect(x: 10, y: 10, width: 100, height: 60))
    }

    func testShadowPaddingFollowsOffsetAndBlur() {
        var s = FrameStyle(); s.shadowEnabled = true; s.shadowBlur = 20; s.shadowOffsetX = 0; s.shadowOffsetY = 10
        let l = FrameLayout.compute(imageSize: size, style: s, unit: 1)
        // left 20, right 20, top 10, bottom 30
        XCTAssertEqual(l.canvas, CGSize(width: 140, height: 100))
        XCTAssertEqual(l.card.origin, CGPoint(x: 20, y: 30))   // bottom padding is the card's y in CG coordinates
    }

    func testMarginWinsOverSmallerShadowPadding() {
        var s = FrameStyle(); s.shadowEnabled = true; s.shadowBlur = 5; s.margin = 40
        let l = FrameLayout.compute(imageSize: size, style: s, unit: 1)
        XCTAssertEqual(l.canvas, CGSize(width: 180, height: 140))
    }

    func testWindowChromeAddsTitleBarAboveContent() {
        var s = FrameStyle(); s.windowChrome = true
        let l = FrameLayout.compute(imageSize: size, style: s, unit: 1)
        XCTAssertEqual(l.canvas, CGSize(width: 100, height: 88))
        XCTAssertEqual(l.content, CGRect(x: 0, y: 0, width: 100, height: 60))
        XCTAssertEqual(l.titleBar, CGRect(x: 0, y: 60, width: 100, height: 28))
    }

    func testUnitScalesLengthsAndCornerRadiusIsClamped() {
        var s = FrameStyle(); s.margin = 10; s.cornerRadius = 500
        let l = FrameLayout.compute(imageSize: size, style: s, unit: 2)
        XCTAssertEqual(l.canvas, CGSize(width: 140, height: 100))     // 20 px margin on each side
        XCTAssertEqual(l.cornerRadius, 30)                             // half of the shorter card side
    }

    func testStyleRoundTripsThroughJSON() throws {
        var s = FrameStyle(); s.cornerRadius = 12; s.windowChrome = true; s.title = "Notes"; s.shadowEnabled = true
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(FrameStyle.self, from: data), s)
    }
}
