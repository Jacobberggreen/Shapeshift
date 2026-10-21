import XCTest
import ImageIO
@testable import EditCore

final class ImageWriterTests: XCTestCase {
    private let noise = noiseImage(width: 300, height: 300)

    func testLowerQualityGivesSmallerJPEG() throws {
        let high = try ImageWriter.encode(noise, format: .jpeg, quality: 0.95, metadata: nil)
        let low = try ImageWriter.encode(noise, format: .jpeg, quality: 0.2, metadata: nil)
        XCTAssertLessThan(low.count, high.count)
    }

    func testEncodedTypeMatchesFormat() throws {
        for (format, uti) in [(ImageOutputFormat.jpeg, "public.jpeg"), (.png, "public.png"), (.tiff, "public.tiff"),
                              (.bmp, "com.microsoft.bmp"), (.gif, "com.compuserve.gif"), (.heic, "public.heic")] {
            let data = try ImageWriter.encode(solidImage(width: 32, height: 32), format: format, quality: 0.8, metadata: nil)
            let src = CGImageSourceCreateWithData(data as CFData, nil)!
            XCTAssertEqual(CGImageSourceGetType(src) as String?, uti, "\(format)")
        }
    }

    func testMetadataNilStripsEverythingAndKeepingCopiesGPS() throws {
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 59.3, kCGImagePropertyGPSLatitudeRef: "N",
                                    kCGImagePropertyGPSLongitude: 18.0, kCGImagePropertyGPSLongitudeRef: "E"]
        let meta: [CFString: Any] = [kCGImagePropertyGPSDictionary: gps,
                                     kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Acme"]]
        let kept = try ImageWriter.encode(solidImage(width: 32, height: 32), format: .jpeg, quality: 0.9, metadata: meta)
        XCTAssertNotNil(properties(ofData: kept)?[kCGImagePropertyGPSDictionary])
        let stripped = try ImageWriter.encode(solidImage(width: 32, height: 32), format: .jpeg, quality: 0.9, metadata: nil)
        XCTAssertNil(properties(ofData: stripped)?[kCGImagePropertyGPSDictionary])
        let tiff = properties(ofData: stripped)?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertNil(tiff?[kCGImagePropertyTIFFMake])
    }

    func testFitLandsAtOrUnderTarget() throws {
        let full = try ImageWriter.encode(noise, format: .jpeg, quality: 1, metadata: nil)
        let target = full.count / 3
        let result = try ImageWriter.fit(noise, format: .jpeg, targetBytes: target, metadata: nil)
        XCTAssertLessThanOrEqual(result.data.count, target)
        XCTAssertGreaterThan(result.data.count, target / 4)           // not wastefully tiny
        XCTAssertLessThan(result.quality, 1)
    }

    func testFitReturnsAtQualityOneWhenAlreadySmallEnough() throws {
        let result = try ImageWriter.fit(solidImage(width: 16, height: 16), format: .jpeg, targetBytes: 1_000_000, metadata: nil)
        XCTAssertEqual(result.quality, 1, accuracy: 0.0001)
    }

    func testFitThrowsWhenTargetUnreachable() {
        XCTAssertThrowsError(try ImageWriter.fit(noise, format: .jpeg, targetBytes: 50, metadata: nil)) { error in
            XCTAssertEqual(error as? EditError, .targetNotReachable)
        }
    }

    func testFitRejectsLosslessFormats() {
        XCTAssertThrowsError(try ImageWriter.fit(noise, format: .png, targetBytes: 1000, metadata: nil))
    }

    func testEstimateScalesWithPixelCount() throws {
        let small = resized(noise, width: 100, height: 100)
        let one = try ImageWriter.estimateBytes(preview: small, fullPixelCount: 100 * 100, format: .jpeg, quality: 0.8, metadata: nil)
        let nine = try ImageWriter.estimateBytes(preview: small, fullPixelCount: 300 * 300, format: .jpeg, quality: 0.8, metadata: nil)
        XCTAssertEqual(Double(nine) / Double(one), 9, accuracy: 0.5)
    }

    func testWriteCreatesFile() throws {
        let dir = TemporaryDirectory()
        try ImageWriter.write(solidImage(width: 20, height: 20), format: .png, quality: 1, metadata: nil, to: dir.file("o.png"))
        XCTAssertGreaterThan(try Data(contentsOf: dir.file("o.png")).count, 0)
    }
}
