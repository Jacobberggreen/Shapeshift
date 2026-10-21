import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import EditCore

final class ImageLoaderTests: XCTestCase {
    func testLoadFullReturnsPixelSize() throws {
        let dir = TemporaryDirectory()
        writeImage(solidImage(width: 100, height: 50), to: dir.file("a.png"))
        let img = try ImageLoader.loadFull(url: dir.file("a.png"))
        XCTAssertEqual(img.width, 100); XCTAssertEqual(img.height, 50)
    }

    func testPreviewIsDownscaledAndReportsFullSize() throws {
        let dir = TemporaryDirectory()
        writeImage(solidImage(width: 100, height: 50), to: dir.file("a.png"))
        let p = try ImageLoader.loadPreview(url: dir.file("a.png"), maxSide: 40)
        XCTAssertEqual(max(p.image.width, p.image.height), 40)
        XCTAssertEqual(p.fullSize, CGSize(width: 100, height: 50))
        XCTAssertEqual(p.scale, 0.4, accuracy: 0.02)
    }

    func testPreviewOfSmallImageIsNotUpscaled() throws {
        let dir = TemporaryDirectory()
        writeImage(solidImage(width: 30, height: 20), to: dir.file("a.png"))
        let p = try ImageLoader.loadPreview(url: dir.file("a.png"), maxSide: 1600)
        XCTAssertEqual(p.image.width, 30)
        XCTAssertEqual(p.scale, 1, accuracy: 0.0001)
    }

    func testOrientationIsBakedIntoPixels() throws {
        let dir = TemporaryDirectory()
        // Stored 100x50 with EXIF orientation 6 (rotate 90 CW) => displayed 50x100.
        writeImage(solidImage(width: 100, height: 50), to: dir.file("o.jpg"), type: .jpeg,
                   properties: [kCGImagePropertyOrientation: 6])
        let full = try ImageLoader.loadFull(url: dir.file("o.jpg"))
        XCTAssertEqual(full.width, 50); XCTAssertEqual(full.height, 100)
        let p = try ImageLoader.loadPreview(url: dir.file("o.jpg"), maxSide: 1600)
        XCTAssertEqual(p.fullSize, CGSize(width: 50, height: 100))
    }

    func testUnreadableFileThrows() {
        let dir = TemporaryDirectory()
        try? Data("junk".utf8).write(to: dir.file("bad.png"))
        XCTAssertThrowsError(try ImageLoader.loadFull(url: dir.file("bad.png"))) { error in
            XCTAssertEqual(error as? EditError, .unreadable("bad.png"))
        }
        XCTAssertThrowsError(try ImageLoader.loadPreview(url: dir.file("missing.png")))
    }

    func testSourceMetadataKeepsGPSAndDropsOrientationAndDimensions() {
        let dir = TemporaryDirectory()
        let props: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Acme", kCGImagePropertyTIFFOrientation: 6],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "hello",
                                             kCGImagePropertyExifPixelXDimension: 100],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 59.3, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 18.0, kCGImagePropertyGPSLongitudeRef: "E"],
        ]
        writeImage(solidImage(width: 100, height: 50), to: dir.file("m.jpg"), type: .jpeg, properties: props)
        let meta = ImageLoader.sourceMetadata(url: dir.file("m.jpg"))
        XCTAssertNotNil(meta[kCGImagePropertyGPSDictionary])
        XCTAssertNil(meta[kCGImagePropertyOrientation])
        let tiff = meta[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFMake] as? String, "Acme")
        XCTAssertNil(tiff?[kCGImagePropertyTIFFOrientation])
        let exif = meta[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifPixelXDimension])
    }

    func testLoadsSVGAsBitmap() throws {
        let dir = TemporaryDirectory()
        let svg = dir.file("a.svg")
        try """
        <svg xmlns="http://www.w3.org/2000/svg" width="120" height="60"><rect width="120" height="60" fill="red"/></svg>
        """.write(to: svg, atomically: true, encoding: .utf8)
        let full = try ImageLoader.loadFull(url: svg)
        XCTAssertEqual(Double(full.width) / Double(full.height), 2, accuracy: 0.01)
        let preview = try ImageLoader.loadPreview(url: svg, maxSide: 400)
        XCTAssertEqual(preview.image.width, 400)
    }
}
