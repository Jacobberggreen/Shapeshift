import XCTest
import EditCore
@testable import ShapeshiftApp

final class CropGeometryTests: XCTestCase {
    private let square = CGSize(width: 100, height: 100)
    private let rect = NormalizedRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)

    func testAspectRatios() {
        XCTAssertNil(CropAspect.free.ratio(imageSize: square))
        XCTAssertEqual(CropAspect.square.ratio(imageSize: square), 1)
        XCTAssertEqual(CropAspect.fourThree.ratio(imageSize: square)!, 4.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(CropAspect.sixteenNine.ratio(imageSize: square)!, 16.0 / 9, accuracy: 0.0001)
        XCTAssertEqual(CropAspect.original.ratio(imageSize: CGSize(width: 200, height: 100))!, 2, accuracy: 0.0001)
    }

    func testInitialFreeIsCentredEightyPercent() {
        let r = CropGeometry.initial(aspect: .free, imageSize: square)
        XCTAssertEqual(r.x, 0.1, accuracy: 0.0001); XCTAssertEqual(r.width, 0.8, accuracy: 0.0001)
    }

    func testInitialWithRatioHasThatPixelAspectAndFits() {
        let size = CGSize(width: 200, height: 100)
        let r = CropGeometry.initial(aspect: .square, imageSize: size)
        XCTAssertEqual(r.width * 200 / (r.height * 100), 1, accuracy: 0.01)
        XCTAssertLessThanOrEqual(r.x + r.width, 1); XCTAssertLessThanOrEqual(r.y + r.height, 1)
        XCTAssertEqual(r.x + r.width / 2, 0.5, accuracy: 0.01)            // centred
    }

    func testMoveKeepsSizeAndClampsToImage() {
        let m = CropGeometry.moved(rect, by: CGSize(width: 0.1, height: -0.5))
        XCTAssertEqual(m.x, 0.3, accuracy: 0.0001)
        XCTAssertEqual(m.y, 0, accuracy: 0.0001)
        XCTAssertEqual(m.width, 0.4, accuracy: 0.0001)
        let far = CropGeometry.moved(rect, by: CGSize(width: 5, height: 5))
        XCTAssertEqual(far.x + far.width, 1, accuracy: 0.0001)
        XCTAssertEqual(far.y + far.height, 1, accuracy: 0.0001)
    }

    func testResizeFreeBottomRight() {
        let r = CropGeometry.resized(rect, handle: .bottomRight, to: CGPoint(x: 0.9, y: 0.8), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x, 0.2, accuracy: 0.0001); XCTAssertEqual(r.y, 0.2, accuracy: 0.0001)
        XCTAssertEqual(r.width, 0.7, accuracy: 0.0001); XCTAssertEqual(r.height, 0.6, accuracy: 0.0001)
    }

    func testResizeFreeTopLeftAnchorsOppositeCorner() {
        let r = CropGeometry.resized(rect, handle: .topLeft, to: CGPoint(x: 0.1, y: 0.05), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x + r.width, 0.6, accuracy: 0.0001)               // maxX stays
        XCTAssertEqual(r.y + r.height, 0.6, accuracy: 0.0001)              // maxY stays
        XCTAssertEqual(r.x, 0.1, accuracy: 0.0001); XCTAssertEqual(r.y, 0.05, accuracy: 0.0001)
    }

    func testResizeClampsToImageBounds() {
        let r = CropGeometry.resized(rect, handle: .bottomRight, to: CGPoint(x: 1.7, y: 2), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x + r.width, 1, accuracy: 0.0001); XCTAssertEqual(r.y + r.height, 1, accuracy: 0.0001)
    }

    func testResizeEnforcesMinimumSide() {
        let r = CropGeometry.resized(rect, handle: .bottomRight, to: CGPoint(x: 0.21, y: 0.21), ratio: nil, imageSize: square)
        XCTAssertGreaterThanOrEqual(r.width, 0.05); XCTAssertGreaterThanOrEqual(r.height, 0.05)
    }

    func testResizeWithSquareRatioStaysSquareInPixels() {
        let size = CGSize(width: 200, height: 100)
        let start = NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.4)       // 40 x 40 px
        let r = CropGeometry.resized(start, handle: .bottomRight, to: CGPoint(x: 0.6, y: 0.5), ratio: 1, imageSize: size)
        XCTAssertEqual(r.width * 200, r.height * 100, accuracy: 0.5)
        XCTAssertEqual(r.x, 0.1, accuracy: 0.0001); XCTAssertEqual(r.y, 0.1, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(r.y + r.height, 1.0001)
    }

    func testResizeWithRatioShrinksToFitBounds() {
        let size = CGSize(width: 100, height: 100)
        let start = NormalizedRect(x: 0.6, y: 0.6, width: 0.2, height: 0.2)
        let r = CropGeometry.resized(start, handle: .topLeft, to: CGPoint(x: 0, y: 0.5), ratio: 2, imageSize: size)
        XCTAssertEqual(r.x + r.width, 0.8, accuracy: 0.0001); XCTAssertEqual(r.y + r.height, 0.8, accuracy: 0.0001)
        XCTAssertEqual(r.x, 0, accuracy: 0.0001); XCTAssertEqual(r.y, 0.4, accuracy: 0.0001)
        XCTAssertEqual(r.width, 0.8, accuracy: 0.0001); XCTAssertEqual(r.height, 0.4, accuracy: 0.0001)
    }

    private let corner = NormalizedRect(x: 0.6, y: 0.6, width: 0.4, height: 0.4)

    private func assertInside(_ r: NormalizedRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(r.x, 0, file: file, line: line); XCTAssertGreaterThanOrEqual(r.y, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(r.x + r.width, 1.0001, file: file, line: line); XCTAssertLessThanOrEqual(r.y + r.height, 1.0001, file: file, line: line)
    }

    /// Anchor is (1,1); pointer clamps to (1,1). No room to the right/below, so it flips left/up.
    func testResizeTopLeftFromBottomRightCornerFlipsToRoomySide() {
        let r = CropGeometry.resized(corner, handle: .topLeft, to: CGPoint(x: 1.2, y: 1.2), ratio: nil, imageSize: square)
        XCTAssertGreaterThanOrEqual(r.width, 0.05); XCTAssertGreaterThanOrEqual(r.height, 0.05)
        assertInside(r)
    }

    func testResizeTopLeftFromBottomRightCornerWithRatio() {
        let r = CropGeometry.resized(corner, handle: .topLeft, to: CGPoint(x: 1.2, y: 1.2), ratio: 1, imageSize: square)
        XCTAssertGreaterThan(r.width, 0); XCTAssertGreaterThan(r.height, 0)
        XCTAssertEqual(r.width / r.height, 1, accuracy: 0.01)
        assertInside(r)
    }

    func testResizeFlipsAcrossAnchor() {
        let r = CropGeometry.resized(rect, handle: .bottomRight, to: CGPoint(x: 0.1, y: 0.05), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x, 0.1, accuracy: 0.0001); XCTAssertEqual(r.y, 0.05, accuracy: 0.0001)
        XCTAssertEqual(r.width, 0.1, accuracy: 0.0001); XCTAssertEqual(r.height, 0.15, accuracy: 0.0001)
    }

    func testResizeFreeTopRight() {
        let r = CropGeometry.resized(rect, handle: .topRight, to: CGPoint(x: 0.7, y: 0.3), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x, 0.2, accuracy: 0.0001); XCTAssertEqual(r.y, 0.3, accuracy: 0.0001)
        XCTAssertEqual(r.width, 0.5, accuracy: 0.0001); XCTAssertEqual(r.height, 0.3, accuracy: 0.0001)
    }

    func testResizeFreeBottomLeft() {
        let r = CropGeometry.resized(rect, handle: .bottomLeft, to: CGPoint(x: 0.3, y: 0.7), ratio: nil, imageSize: square)
        XCTAssertEqual(r.x, 0.3, accuracy: 0.0001); XCTAssertEqual(r.y, 0.2, accuracy: 0.0001)
        XCTAssertEqual(r.width, 0.3, accuracy: 0.0001); XCTAssertEqual(r.height, 0.5, accuracy: 0.0001)
    }

    func testResizeTallRatioBindsOnWidthRoom() {
        let start = NormalizedRect(x: 0.5, y: 0.1, width: 0.2, height: 0.2)
        let r = CropGeometry.resized(start, handle: .bottomRight, to: CGPoint(x: 0.95, y: 0.9), ratio: 0.5, imageSize: square)
        XCTAssertEqual(r.width / r.height, 0.5, accuracy: 0.01)
        assertInside(r)
    }
}
