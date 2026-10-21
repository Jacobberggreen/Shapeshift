import XCTest
import ImageIO
@testable import ConversionCore

final class ImageConverterTests: XCTestCase {
    private func inspect(_ url: URL) -> (type: String, width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(src) as String?,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (type, w, h)
    }

    func testConvertsPNGToEachWritableFormat() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.png")
        makeTestPNG(at: input, width: 64, height: 32)
        let expected: [(FileFormat, String)] = [
            (.jpeg, "public.jpeg"), (.tiff, "public.tiff"), (.bmp, "com.microsoft.bmp"),
            (.gif, "com.compuserve.gif"), (.heic, "public.heic"),
        ]
        for (format, uti) in expected {
            let out = dir.file("out.\(format.fileExtension)")
            try await ImageConverter().convert(input: input, from: .png, to: format, output: out, options: ConversionOptions())
            let info = try XCTUnwrap(inspect(out), "\(format) output unreadable")
            XCTAssertEqual(info.type, uti)
            XCTAssertEqual(info.width, 64)
            XCTAssertEqual(info.height, 32)
        }
    }

    func testSupportsOnlyImageToWritableImage() {
        let c = ImageConverter()
        XCTAssertTrue(c.supports(from: .png, to: .jpeg))
        XCTAssertTrue(c.supports(from: .webp, to: .png))
        XCTAssertFalse(c.supports(from: .png, to: .png))
        XCTAssertFalse(c.supports(from: .png, to: .webp))
        XCTAssertFalse(c.supports(from: .png, to: .mp3))
        XCTAssertFalse(c.supports(from: .mp3, to: .png))
    }

    func testUnreadableInputThrows() async {
        let dir = TemporaryDirectory()
        let bogus = dir.file("bogus.png")
        try? Data("not an image".utf8).write(to: bogus)
        do {
            try await ImageConverter().convert(input: bogus, from: .png, to: .jpeg, output: dir.file("o.jpg"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unreadable(bogus))
        }
    }

    func testSVGToPNGRasterizesAtLeastNaturalSize() async throws {
        let dir = TemporaryDirectory()
        let svg = dir.file("in.svg")
        try """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100"><rect width="200" height="100" fill="#0099ff"/></svg>
        """.write(to: svg, atomically: true, encoding: .utf8)
        let out = dir.file("out.png")
        try await ImageConverter().convert(input: svg, from: .svg, to: .png, output: out, options: ConversionOptions())
        let info = try XCTUnwrap(inspect(out))
        XCTAssertEqual(info.type, "public.png")
        XCTAssertEqual(Double(info.width) / Double(info.height), 2, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(info.width, 200)
    }

    func testPNGToSVGWritesAnSVGEmbeddingThePixels() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.png")
        makeTestPNG(at: input, width: 64, height: 32)
        let out = dir.file("out.svg")
        try await ImageConverter().convert(input: input, from: .png, to: .svg, output: out, options: ConversionOptions())
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertTrue(text.contains("<svg"))
        XCTAssertTrue(text.contains("width=\"64\" height=\"32\""))
        XCTAssertTrue(text.contains("data:image/png;base64,"))
        // Round trip: the SVG we wrote can be read back.
        let back = dir.file("back.png")
        try await ImageConverter().convert(input: out, from: .svg, to: .png, output: back, options: ConversionOptions())
        XCTAssertNotNil(inspect(back))
    }

    func testSVGIsOfferedBothWays() {
        XCTAssertTrue(FormatTable.candidateTargets(from: .png).contains(.svg))
        XCTAssertTrue(FormatTable.candidateTargets(from: .svg).contains(.png))
        XCTAssertFalse(FormatTable.candidateTargets(from: .svg).contains(.svg))
        XCTAssertEqual(FileFormat(fileExtension: "SVG"), .svg)
    }
}
