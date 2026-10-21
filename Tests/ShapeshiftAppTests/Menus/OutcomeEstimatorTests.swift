import XCTest
import ImageIO
import UniformTypeIdentifiers
import ConversionCore
@testable import ShapeshiftApp

final class OutcomeEstimatorTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("outcome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makePNG(_ name: String, side: Int = 200) throws -> URL {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for y in 0..<side {
            ctx.setFillColor(CGColor(red: CGFloat(y) / CGFloat(side), green: 0.4, blue: 0.7, alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: side, height: 1))
        }
        let url = dir.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    private func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func bump() { lock.lock(); n += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    }

    func testConstructionDoesNotReadSizesOrDecode() async throws {
        let png = try makePNG("a.png")
        let sizes = Counter(), decodes = Counter()
        let source = OutcomeEstimator.source(for: [png], quality: 0.8,
                                             sizeProvider: { _ in sizes.bump(); return 10 },
                                             previewLoader: { _ in decodes.bump(); return nil })
        XCTAssertEqual(sizes.value, 0)
        XCTAssertEqual(decodes.value, 0)
        XCTAssertNil(source.sourceBytes)
        let bytes = await source.sourceBytesProvider?()
        XCTAssertEqual(bytes, 10)
        XCTAssertEqual(sizes.value, 1)
    }

    func testSecondFormatReusesTheFirstDecode() async throws {
        let png = try makePNG("a.png")
        let decodes = Counter()
        let source = OutcomeEstimator.source(for: [png], quality: 0.8, previewLoader: { url in
            decodes.bump()
            return OutcomeEstimator.loadPreview(url)
        })
        let jpeg = await source.estimate?(.jpeg)
        let heic = await source.estimate?(.heic)
        XCTAssertGreaterThan(jpeg ?? 0, 0)
        XCTAssertNotNil(heic)
        XCTAssertEqual(decodes.value, 1)
    }

    func testImageSourceHasFormatSizeAndAnEstimator() async throws {
        let png = try makePNG("a.png")
        let source = OutcomeEstimator.source(for: [png], quality: 0.8)
        XCTAssertEqual(source.sourceFormat, .png)
        let size = await source.sourceBytesProvider?()
        XCTAssertEqual(size, fileSize(png))
        let jpeg = await source.estimate?(.jpeg)
        XCTAssertGreaterThan(jpeg ?? 0, 0)
    }

    func testUnwritableTargetHasNoEstimate() async throws {
        let png = try makePNG("a.png")
        let source = OutcomeEstimator.source(for: [png], quality: 0.8)
        let webp = await source.estimate?(.webp)
        XCTAssertNil(webp)
    }

    func testNonImagesHaveNoEstimator() async throws {
        let mp3 = dir.appendingPathComponent("a.mp3")
        try Data(repeating: 1, count: 1234).write(to: mp3)
        let source = OutcomeEstimator.source(for: [mp3], quality: 0.8)
        XCTAssertEqual(source.sourceFormat, .mp3)
        let size = await source.sourceBytesProvider?()
        XCTAssertEqual(size, 1234)
        XCTAssertNil(source.estimate)
    }

    func testMixedFilesSumSizesAndDropTheFormat() async throws {
        let png = try makePNG("a.png")
        let mp3 = dir.appendingPathComponent("a.mp3")
        try Data(repeating: 1, count: 500).write(to: mp3)
        let source = OutcomeEstimator.source(for: [png, mp3], quality: 0.8)
        XCTAssertNil(source.sourceFormat)
        let size = await source.sourceBytesProvider?()
        XCTAssertEqual(size, fileSize(png) + 500)
        XCTAssertNil(source.estimate)
    }

    func testZeroByteFirstFileDoesNotDivideByZero() async throws {
        let empty = dir.appendingPathComponent("empty.png")
        try Data().write(to: empty)
        let png = try makePNG("b.png")
        let source = OutcomeEstimator.source(for: [empty, png], quality: 0.8)
        let size = await source.sourceBytesProvider?()
        XCTAssertEqual(size, fileSize(png))
        XCTAssertNotNil(source.estimate)
        // The (empty) first file is unreadable, so nil, but constructing must not trap.
        let value = await source.estimate?(.jpeg)
        XCTAssertNil(value)
    }

    func testUnreadableImageYieldsNilEstimate() async throws {
        let bad = dir.appendingPathComponent("bad.png")
        try Data(repeating: 7, count: 300).write(to: bad)
        let source = OutcomeEstimator.source(for: [bad], quality: 0.8)
        let value = await source.estimate?(.jpeg)
        XCTAssertNil(value)
    }
}
