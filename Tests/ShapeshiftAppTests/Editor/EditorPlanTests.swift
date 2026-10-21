import XCTest
import EditCore
@testable import ShapeshiftApp

final class EditorPlanTests: XCTestCase {
    func testDefaultPlanHasNoWork() {
        XCTAssertFalse(EditorPlan().hasWork(forExtension: "jpg"))
        XCTAssertTrue(EditorPlan().pipeline().isEmpty)
    }

    func testPipelineContainsEnabledStepsOnly() {
        var plan = EditorPlan()
        plan.cropEnabled = true; plan.crop = NormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        XCTAssertEqual(plan.pipeline().crop?.rect.width, 0.5)
        XCTAssertNil(plan.pipeline().frame)
        plan.frameEnabled = true
        XCTAssertNotNil(plan.pipeline().frame)
    }

    func testFrameForcesPNGOtherwiseSourceFormatWithWebPFallback() {
        var plan = EditorPlan()
        XCTAssertEqual(plan.outputFormat(forExtension: "jpg"), .jpeg)
        XCTAssertEqual(plan.outputFormat(forExtension: "HEIC"), .heic)
        XCTAssertEqual(plan.outputFormat(forExtension: "webp"), .png)
        plan.frameEnabled = true
        XCTAssertEqual(plan.outputFormat(forExtension: "jpg"), .png)
    }

    func testCompressOnlyAppliesToLossyOutputs() {
        var plan = EditorPlan(); plan.compressEnabled = true
        XCTAssertTrue(plan.compressApplies(to: .jpeg))
        XCTAssertTrue(plan.compressApplies(to: .heic))
        XCTAssertFalse(plan.compressApplies(to: .png))
        XCTAssertFalse(plan.hasWork(forExtension: "png"))        // compress alone on a PNG does nothing
        XCTAssertTrue(plan.hasWork(forExtension: "jpg"))
    }

    func testExportSettingsUseQualityOrTargetSize() {
        var plan = EditorPlan(); plan.baseQuality = 0.7
        XCTAssertEqual(plan.exportSettings(forExtension: "jpg").quality, 0.7)
        plan.compressEnabled = true; plan.compress = .quality(0.4)
        XCTAssertEqual(plan.exportSettings(forExtension: "jpg").quality, 0.4)
        XCTAssertNil(plan.exportSettings(forExtension: "jpg").targetBytes)
        plan.compress = .targetBytes(50_000)
        XCTAssertEqual(plan.exportSettings(forExtension: "jpg").targetBytes, 50_000)
        XCTAssertNil(plan.exportSettings(forExtension: "png").targetBytes)       // lossless: not applicable
    }

    func testLabelOrderAndContents() {
        var plan = EditorPlan()
        plan.stripMetadata = true
        XCTAssertEqual(plan.label(forExtension: "jpg"), "clean")
        plan.cropEnabled = true; plan.compressEnabled = true
        XCTAssertEqual(plan.label(forExtension: "jpg"), "cropped compressed clean")
        XCTAssertEqual(plan.label(forExtension: "png"), "cropped clean")          // PNG is lossless: compress not applicable
        plan.frameEnabled = true
        XCTAssertEqual(plan.label(forExtension: "jpg"), "cropped framed clean")   // Frame forces PNG: compress not applicable
    }

    func testToolMetadata() {
        XCTAssertEqual(EditTool.allCases.map(\.title), ["Frame", "Crop", "Compress", "Strip metadata"])
    }
}
