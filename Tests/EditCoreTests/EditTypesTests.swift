import XCTest
import CoreGraphics
@testable import EditCore

final class EditTypesTests: XCTestCase {
    func testQuadrantFixtureIsTopFirst() {
        // Guards the pixel() helper itself: (0,0) must be the visual top-left.
        let img = quadrantImage(width: 20, height: 20)
        XCTAssertTrue(isClose(pixel(img, x: 2, y: 2), 255, 0, 0))
        XCTAssertTrue(isClose(pixel(img, x: 17, y: 2), 0, 255, 0))
        XCTAssertTrue(isClose(pixel(img, x: 2, y: 17), 0, 0, 255))
        XCTAssertTrue(isClose(pixel(img, x: 17, y: 17), 255, 255, 255))
    }

    func testUnitScalesWithLongestSideAndPreviewScale() {
        XCTAssertEqual(EditContext(scale: 1, referenceLongSide: 500).unit, 1, accuracy: 0.0001)
        XCTAssertEqual(EditContext(scale: 1, referenceLongSide: 3000).unit, 3, accuracy: 0.0001)
        XCTAssertEqual(EditContext(scale: 0.5, referenceLongSide: 3000).unit, 1.5, accuracy: 0.0001)
    }

    func testColorRoundTripAndCGColor() throws {
        let c = RGBAColor(r: 0.1, g: 0.2, b: 0.3, a: 0.4)
        let decoded = try JSONDecoder().decode(RGBAColor.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(decoded, c)
        XCTAssertEqual(c.cgColor.numberOfComponents, 4)
    }

    func testOutputFormatMapping() {
        XCTAssertEqual(ImageOutputFormat(fileExtension: "JPG"), .jpeg)
        XCTAssertEqual(ImageOutputFormat(fileExtension: "heif"), .heic)
        XCTAssertNil(ImageOutputFormat(fileExtension: "webp"))
        XCTAssertEqual(ImageOutputFormat.jpeg.fileExtension, "jpg")
        XCTAssertTrue(ImageOutputFormat.jpeg.isLossy)
        XCTAssertTrue(ImageOutputFormat.heic.isLossy)
        XCTAssertFalse(ImageOutputFormat.png.isLossy)
        XCTAssertTrue(ImageOutputFormat.jpeg.supportsMetadata)
        XCTAssertFalse(ImageOutputFormat.png.supportsMetadata)
    }

    func testNormalizedRectPixelRectRoundsAndClamps() {
        let size = CGSize(width: 200, height: 100)
        XCTAssertEqual(NormalizedRect.full.pixelRect(in: size), CGRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertEqual(NormalizedRect(x: 0.5, y: 0.5, width: 0.25, height: 0.5).pixelRect(in: size),
                       CGRect(x: 100, y: 50, width: 50, height: 50))
        // Overflowing and degenerate rects are clamped to a valid >= 1 px rect inside the image.
        let r = NormalizedRect(x: 0.9, y: 0.9, width: 0.5, height: 0.0).pixelRect(in: size)
        XCTAssertGreaterThanOrEqual(r.width, 1); XCTAssertGreaterThanOrEqual(r.height, 1)
        XCTAssertLessThanOrEqual(r.maxX, 200); XCTAssertLessThanOrEqual(r.maxY, 100)
    }
}
