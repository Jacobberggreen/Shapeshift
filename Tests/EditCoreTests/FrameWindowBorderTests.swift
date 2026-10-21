import XCTest
@testable import EditCore

final class FrameWindowBorderTests: XCTestCase {
    private let ctx = EditContext(scale: 1, referenceLongSide: 100)   // unit == 1

    private func chrome(theme: WindowTheme = .light) -> FrameStyle {
        var s = FrameStyle(); s.windowChrome = true; s.theme = theme
        return s
    }

    private func render(_ style: FrameStyle, context: EditContext? = nil,
                        width: Int = 100, height: Int = 100) throws -> CGImage {
        try FrameStep(style: style).apply(to: solidImage(width: width, height: height), context: context ?? ctx)
    }

    func testChromeIgnoresBorderWidthAndColour() throws {
        var thick = chrome(); thick.borderWidth = 12; thick.borderColor = RGBAColor(r: 0, g: 0, b: 1)
        XCTAssertLessThan(meanAbsoluteDifference(try render(chrome()), try render(thick)), 0.01)
    }

    func testLightHairlineDarkensTheCardEdge() throws {
        let out = try render(chrome())            // canvas 100 x 128; y == 80 is inside the image area either way up
        XCTAssertTrue(isClose(pixel(out, x: 0, y: 80), 209, 0, 0, tolerance: 6))    // black 18 % over red
        XCTAssertTrue(isClose(pixel(out, x: 99, y: 80), 209, 0, 0, tolerance: 6))
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 80), 255, 0, 0))                  // interior untouched
    }

    func testDarkHairlineLightensTheCardEdge() throws {
        let out = try render(chrome(theme: .dark))
        XCTAssertTrue(isClose(pixel(out, x: 0, y: 80), 255, 56, 56, tolerance: 6))   // white 22 % over red
    }

    func testHairlineScalesWithUnit() throws {
        let big = EditContext(scale: 1, referenceLongSide: 2000)     // unit == 2 → 2 px hairline, 56 px title bar
        let out = try render(chrome(), context: big, width: 200, height: 100)
        XCTAssertTrue(isClose(pixel(out, x: 1, y: 70), 209, 0, 0, tolerance: 6))
        XCTAssertTrue(isClose(pixel(out, x: 3, y: 70), 255, 0, 0))
    }
}
