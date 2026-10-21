import XCTest
@testable import EditCore

final class FrameStepTests: XCTestCase {
    private let ctx = EditContext(scale: 1, referenceLongSide: 100)   // unit == 1
    private func render(_ style: FrameStyle, _ image: CGImage? = nil) throws -> CGImage {
        try FrameStep(style: style).apply(to: image ?? solidImage(width: 100, height: 100), context: ctx)
    }

    func testDefaultStyleLeavesImageUnchanged() throws {
        let src = quadrantImage(width: 100, height: 100)
        let out = try render(FrameStyle(), src)
        XCTAssertEqual(out.width, 100); XCTAssertEqual(out.height, 100)
        XCTAssertLessThan(meanAbsoluteDifference(src, out), 1)
    }

    func testRoundedCornersAreTransparentAndCentreIsOpaque() throws {
        var s = FrameStyle(); s.cornerRadius = 20
        let out = try render(s)
        XCTAssertEqual(pixel(out, x: 0, y: 0).a, 0)
        XCTAssertEqual(pixel(out, x: 99, y: 0).a, 0)
        XCTAssertEqual(pixel(out, x: 0, y: 99).a, 0)
        XCTAssertEqual(pixel(out, x: 99, y: 99).a, 0)
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 50), 255, 0, 0))
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 1), 255, 0, 0))     // straight edge stays opaque
    }

    func testBorderIsDrawnInsideTheShape() throws {
        var s = FrameStyle(); s.borderWidth = 6; s.borderColor = RGBAColor(r: 0, g: 0, b: 1)
        let out = try render(s)
        XCTAssertEqual(out.width, 100)                                       // border does not grow the canvas
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 2), 0, 0, 255))
        XCTAssertTrue(isClose(pixel(out, x: 2, y: 50), 0, 0, 255))
        XCTAssertTrue(isClose(pixel(out, x: 97, y: 50), 0, 0, 255))
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 97), 0, 0, 255))
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 10), 255, 0, 0))          // beyond the border: image colour
    }

    func testMarginWithOpaqueBackground() throws {
        var s = FrameStyle(); s.margin = 10; s.backgroundColor = .white
        let out = try render(s)
        XCTAssertEqual(out.width, 120); XCTAssertEqual(out.height, 120)
        XCTAssertTrue(isClose(pixel(out, x: 5, y: 5), 255, 255, 255))
        XCTAssertTrue(isClose(pixel(out, x: 60, y: 60), 255, 0, 0))
    }

    func testMarginWithTransparentBackgroundStaysTransparent() throws {
        var s = FrameStyle(); s.margin = 10
        let out = try render(s)
        XCTAssertEqual(pixel(out, x: 5, y: 5).a, 0)
    }

    func testBackgroundShowsThroughRoundedCorners() throws {
        var s = FrameStyle(); s.cornerRadius = 20; s.backgroundColor = .white
        let out = try render(s)
        XCTAssertTrue(isClose(pixel(out, x: 0, y: 0), 255, 255, 255))
    }

    func testLengthsScaleWithUnit() throws {
        // A 2000 px image: unit == 2, so a 10 pt margin is 20 px per side.
        var s = FrameStyle(); s.margin = 10
        let big = EditContext(scale: 1, referenceLongSide: 2000)
        let out = try FrameStep(style: s).apply(to: solidImage(width: 200, height: 100), context: big)
        XCTAssertEqual(out.width, 240); XCTAssertEqual(out.height, 140)
    }
}

final class FrameShadowTests: XCTestCase {
    private let ctx = EditContext(scale: 1, referenceLongSide: 100)

    private func shadowStyle() -> FrameStyle {
        var s = FrameStyle()
        s.shadowEnabled = true; s.shadowBlur = 20; s.shadowOffsetY = 10
        s.shadowColor = .black; s.shadowOpacity = 1
        return s
    }

    func testCanvasGrowsForShadowAndCardStaysIntact() throws {
        let out = try FrameStep(style: shadowStyle()).apply(to: solidImage(width: 100, height: 100), context: ctx)
        XCTAssertEqual(out.width, 140); XCTAssertEqual(out.height, 140)      // pads: L20 R20 T10 B30
        XCTAssertTrue(isClose(pixel(out, x: 70, y: 60), 255, 0, 0))          // card centre (x=20+50, y=10+50)
    }

    func testShadowIsVisibleBelowTheCardAndWeakAboveIt() throws {
        let out = try FrameStep(style: shadowStyle()).apply(to: solidImage(width: 100, height: 100), context: ctx)
        let below = pixel(out, x: 70, y: 115)      // 5 px under the card bottom (card spans y 10...110)
        let above = pixel(out, x: 70, y: 1)        // above the card top, offset pushes shadow down
        XCTAssertGreaterThan(Int(below.a), 40)
        XCTAssertLessThan(Int(above.a), Int(below.a))
        XCTAssertEqual(pixel(out, x: 0, y: 0).a, 0)                          // far corner untouched
    }

    func testShadowOpacityScalesAlpha() throws {
        var faint = shadowStyle(); faint.shadowOpacity = 0.2
        let strong = try FrameStep(style: shadowStyle()).apply(to: solidImage(width: 100, height: 100), context: ctx)
        let weak = try FrameStep(style: faint).apply(to: solidImage(width: 100, height: 100), context: ctx)
        XCTAssertGreaterThan(Int(pixel(strong, x: 70, y: 115).a), Int(pixel(weak, x: 70, y: 115).a))
    }

    func testShadowFollowsRoundedShape() throws {
        var s = shadowStyle(); s.cornerRadius = 30; s.shadowOffsetY = 0
        let out = try FrameStep(style: s).apply(to: solidImage(width: 100, height: 100), context: ctx)
        // Card spans 20...120 in both axes of the 140x140 canvas.
        let side = pixel(out, x: 70, y: 15)        // just outside the straight top edge, mid-side
        let corner = pixel(out, x: 20, y: 20)      // card's outer bounding-box corner, outside the rounded arc
        XCTAssertGreaterThan(Int(side.a), 40)                       // shadow present
        XCTAssertGreaterThan(Int(corner.a), 0)                      // some shadow reaches the corner
        XCTAssertLessThan(Int(corner.a), Int(side.a))               // hugs the rounded shape, not the bounding box
        XCTAssertTrue(isClose(pixel(out, x: 70, y: 70), 255, 0, 0)) // card centre intact
    }

    func testNoShadowMeansNoGrowth() throws {
        let out = try FrameStep(style: FrameStyle()).apply(to: solidImage(width: 100, height: 100), context: ctx)
        XCTAssertEqual(out.width, 100)
    }
}

final class FrameChromeTests: XCTestCase {
    private let ctx = EditContext(scale: 1, referenceLongSide: 100)

    private func chrome(theme: WindowTheme = .light, inactive: Bool = false, title: String = "") -> FrameStyle {
        var s = FrameStyle(); s.windowChrome = true; s.theme = theme; s.inactive = inactive; s.title = title
        return s
    }
    private func render(_ s: FrameStyle) throws -> CGImage {
        try FrameStep(style: s).apply(to: solidImage(width: 100, height: 60, red: 0, green: 0, blue: 1), context: ctx)
    }

    func testCanvasHasTitleBarAndImageBelow() throws {
        let out = try render(chrome())
        XCTAssertEqual(out.width, 100); XCTAssertEqual(out.height, 88)
        XCTAssertTrue(isClose(pixel(out, x: 50, y: 60), 0, 0, 255))          // content (below the 28 px bar)
        XCTAssertTrue(isClose(pixel(out, x: 90, y: 14), 237, 237, 237))      // light bar
    }

    func testTrafficLightColours() throws {
        let out = try render(chrome())
        XCTAssertTrue(isClose(pixel(out, x: 18, y: 14), 255, 94, 87, tolerance: 6))    // red
        XCTAssertTrue(isClose(pixel(out, x: 38, y: 14), 255, 189, 46, tolerance: 6))   // yellow
        XCTAssertTrue(isClose(pixel(out, x: 58, y: 14), 41, 201, 64, tolerance: 6))    // green
    }

    func testDarkThemeBar() throws {
        let out = try render(chrome(theme: .dark))
        XCTAssertTrue(isClose(pixel(out, x: 90, y: 14), 51, 51, 54, tolerance: 4))
    }

    func testInactiveButtonsAreGray() throws {
        let out = try render(chrome(inactive: true))
        let p = pixel(out, x: 18, y: 14)
        XCTAssertTrue(isClose(p, 204, 204, 204, tolerance: 6))
    }

    func testTitleTextDrawsSomethingInTheBarCentre() throws {
        let plain = try render(chrome())
        let titled = try render(chrome(title: "Notes"))
        XCTAssertGreaterThan(meanAbsoluteDifference(plain, titled), 0.05)
    }

    func testRoundedCornersFollowTheWindowShape() throws {
        var s = chrome(); s.cornerRadius = 14
        let out = try render(s)
        XCTAssertEqual(pixel(out, x: 0, y: 0).a, 0)                          // top-left of the title bar is rounded
        XCTAssertEqual(pixel(out, x: 99, y: 87).a, 0)                        // bottom-right of the image is rounded too
    }

    func testBorderAndShadowStillWorkWithChrome() throws {
        var s = chrome(); s.borderWidth = 2; s.borderColor = RGBAColor(r: 0, g: 0, b: 0); s.shadowEnabled = true
        s.shadowBlur = 10; s.shadowOpacity = 1
        let out = try render(s)
        XCTAssertGreaterThan(out.width, 100)
        XCTAssertGreaterThan(out.height, 88)
    }

    func testFramePreservesDisplayP3AndSRGBColourSpaces() throws {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        let p3Ctx = CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: p3,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        p3Ctx.setFillColor(CGColor(colorSpace: p3, components: [0.9, 0.2, 0.1, 1])!)
        p3Ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        var s = FrameStyle(); s.margin = 4
        let framedP3 = try FrameStep(style: s).apply(to: p3Ctx.makeImage()!, context: ctx)
        XCTAssertEqual(framedP3.colorSpace?.name as String?, CGColorSpace.displayP3 as String)
        let framedSRGB = try FrameStep(style: s).apply(to: solidImage(width: 20, height: 20), context: ctx)
        XCTAssertEqual(framedSRGB.colorSpace?.name as String?, CGColorSpace.sRGB as String)
    }
}
