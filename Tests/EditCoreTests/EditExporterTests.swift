import XCTest
import ImageIO
@testable import EditCore

final class EditExporterTests: XCTestCase {
    private func makeSourceJPEG(in dir: TemporaryDirectory) -> URL {
        let url = dir.file("src.jpg")
        let props: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 59.3, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 18.0, kCGImagePropertyGPSLongitudeRef: "E"],
        ]
        writeImage(quadrantImage(width: 200, height: 100), to: url, type: .jpeg, properties: props)
        return url
    }
    private func props(_ url: URL) -> [CFString: Any]? { properties(ofData: (try? Data(contentsOf: url)) ?? Data()) }

    func testOriginalIsNeverModified() throws {
        let dir = TemporaryDirectory()
        let src = makeSourceJPEG(in: dir)
        let before = try Data(contentsOf: src)
        var style = FrameStyle(); style.cornerRadius = 10
        try EditExporter.export(source: src, pipeline: EditPipeline(frame: FrameStep(style: style)),
                                settings: ExportSettings(format: .png, quality: 1, targetBytes: nil, stripMetadata: true),
                                to: dir.file("out.png"))
        XCTAssertEqual(try Data(contentsOf: src), before)
    }

    func testCropAndFrameProduceExpectedSizePNG() throws {
        let dir = TemporaryDirectory()
        let src = makeSourceJPEG(in: dir)
        var style = FrameStyle(); style.margin = 10
        let pipeline = EditPipeline(crop: CropStep(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)),
                                    frame: FrameStep(style: style))
        try EditExporter.export(source: src, pipeline: pipeline,
                                settings: ExportSettings(format: .png, quality: 1, targetBytes: nil, stripMetadata: true),
                                to: dir.file("out.png"))
        let p = props(dir.file("out.png"))
        XCTAssertEqual(p?[kCGImagePropertyPixelWidth] as? Int, 120)    // 100 + 2*10
        XCTAssertEqual(p?[kCGImagePropertyPixelHeight] as? Int, 120)   // 100 + 2*10
    }

    func testKeepMetadataCopiesGPSForJPEGWithoutFrame() throws {
        let dir = TemporaryDirectory()
        let src = makeSourceJPEG(in: dir)
        let crop = EditPipeline(crop: CropStep(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)))
        try EditExporter.export(source: src, pipeline: crop,
                                settings: ExportSettings(format: .jpeg, quality: 0.9, targetBytes: nil, stripMetadata: false),
                                to: dir.file("kept.jpg"))
        XCTAssertNotNil(props(dir.file("kept.jpg"))?[kCGImagePropertyGPSDictionary])
        try EditExporter.export(source: src, pipeline: crop,
                                settings: ExportSettings(format: .jpeg, quality: 0.9, targetBytes: nil, stripMetadata: true),
                                to: dir.file("clean.jpg"))
        XCTAssertNil(props(dir.file("clean.jpg"))?[kCGImagePropertyGPSDictionary])
    }

    func testEmptyPipelineStripOnlyKeepsDimensions() throws {
        let dir = TemporaryDirectory()
        let src = makeSourceJPEG(in: dir)
        try EditExporter.export(source: src, pipeline: EditPipeline(),
                                settings: ExportSettings(format: .jpeg, quality: 0.9, targetBytes: nil, stripMetadata: true),
                                to: dir.file("clean.jpg"))
        XCTAssertEqual(props(dir.file("clean.jpg"))?[kCGImagePropertyPixelWidth] as? Int, 200)
    }

    func testTargetSizeIsRespectedForJPEG() throws {
        let dir = TemporaryDirectory()
        let src = dir.file("noise.jpg")
        writeImage(noiseImage(width: 300, height: 300), to: src, type: .jpeg)
        let originalSize = try Data(contentsOf: src).count
        let target = originalSize / 3
        try EditExporter.export(source: src, pipeline: EditPipeline(),
                                settings: ExportSettings(format: .jpeg, quality: 1, targetBytes: target, stripMetadata: true),
                                to: dir.file("small.jpg"))
        XCTAssertLessThanOrEqual(try Data(contentsOf: dir.file("small.jpg")).count, target)
    }

    func testUnreachableTargetThrows() {
        let dir = TemporaryDirectory()
        let src = dir.file("noise.jpg")
        writeImage(noiseImage(width: 300, height: 300), to: src, type: .jpeg)
        XCTAssertThrowsError(try EditExporter.export(
            source: src, pipeline: EditPipeline(),
            settings: ExportSettings(format: .jpeg, quality: 1, targetBytes: 40, stripMetadata: true),
            to: dir.file("x.jpg"))) { XCTAssertEqual($0 as? EditError, .targetNotReachable) }
    }

    func testUnreadableSourceThrows() {
        let dir = TemporaryDirectory()
        try? Data("junk".utf8).write(to: dir.file("bad.jpg"))
        XCTAssertThrowsError(try EditExporter.export(
            source: dir.file("bad.jpg"), pipeline: EditPipeline(),
            settings: ExportSettings(format: .jpeg, quality: 1, targetBytes: nil, stripMetadata: true),
            to: dir.file("o.jpg")))
    }
}
