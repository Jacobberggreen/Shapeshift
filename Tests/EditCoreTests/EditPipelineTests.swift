import XCTest
@testable import EditCore

final class EditPipelineTests: XCTestCase {
    func testEmptyPipelineReturnsImageUnchanged() throws {
        let img = quadrantImage(width: 40, height: 30)
        let out = try EditPipeline().render(img, fullSize: CGSize(width: 40, height: 30), scale: 1)
        XCTAssertEqual(out.width, 40); XCTAssertTrue(EditPipeline().isEmpty)
    }

    func testCropThenFrame() throws {
        var style = FrameStyle(); style.margin = 10; style.backgroundColor = .white
        let p = EditPipeline(crop: CropStep(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5)),
                             frame: FrameStep(style: style))
        let out = try p.render(quadrantImage(width: 100, height: 100), fullSize: CGSize(width: 100, height: 100), scale: 1)
        XCTAssertEqual(out.width, 70); XCTAssertEqual(out.height, 70)           // 50 + 2*10
        XCTAssertTrue(isClose(pixel(out, x: 35, y: 35), 255, 0, 0))              // top-left quadrant is red
        XCTAssertTrue(isClose(pixel(out, x: 3, y: 3), 255, 255, 255))
    }

    func testFrameUnitUsesTheCroppedFullSizeLongSide() throws {
        // Full image 4000x2000; crop to the left half (2000x2000) => unit == 2, so margin 10 => 20 px per side.
        var style = FrameStyle(); style.margin = 10
        let p = EditPipeline(crop: CropStep(rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)),
                             frame: FrameStep(style: style))
        let preview = solidImage(width: 400, height: 200)                        // scale 0.1
        let out = try p.render(preview, fullSize: CGSize(width: 4000, height: 2000), scale: 0.1)
        // cropped preview is 200x200; unit = 0.1 * 2 = 0.2 => margin = 2 px per side
        XCTAssertEqual(out.width, 204); XCTAssertEqual(out.height, 204)
    }

    func testPreviewMatchesExportWithinTolerance() throws {
        var style = FrameStyle()
        style.cornerRadius = 24; style.borderWidth = 4; style.borderColor = RGBAColor(r: 0, g: 0, b: 1)
        style.shadowEnabled = true; style.shadowBlur = 16; style.shadowOffsetY = 8; style.shadowOpacity = 0.5
        style.margin = 12; style.backgroundColor = .white
        let pipeline = EditPipeline(frame: FrameStep(style: style))

        let full = quadrantImage(width: 800, height: 600)
        let exported = try pipeline.render(full, fullSize: CGSize(width: 800, height: 600), scale: 1)
        let preview = try pipeline.render(resized(full, width: 400, height: 300),
                                          fullSize: CGSize(width: 800, height: 600), scale: 0.5)

        XCTAssertLessThanOrEqual(abs(preview.width * 2 - exported.width), 4)
        XCTAssertLessThanOrEqual(abs(preview.height * 2 - exported.height), 4)
        let exportedSmall = resized(exported, width: preview.width, height: preview.height)
        XCTAssertLessThan(meanAbsoluteDifference(preview, exportedSmall), 6)
    }
}
