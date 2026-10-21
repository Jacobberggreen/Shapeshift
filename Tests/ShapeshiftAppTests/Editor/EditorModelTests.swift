import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import EditCore
@testable import ShapeshiftApp

@MainActor
final class EditorModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("EditorModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func writeImage(_ name: String, type: UTType) throws -> URL {
        let ctx = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        let url = dir.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    private func makeStore() -> FramePresetStore {
        let suite = "EditorModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return FramePresetStore(defaults: defaults)
    }

    func testCompressToolOnPNGFirstBatchWithJPEGCanStillSave() throws {
        let png = try writeImage("a.png", type: .png)
        let jpg = try writeImage("b.jpg", type: .jpeg)
        let mixed = EditorModel(urls: [png, jpg], initialTool: .compress, presets: makeStore(), baseQuality: 0.85)
        XCTAssertTrue(mixed.canSave)
        let pngOnly = EditorModel(urls: [png], initialTool: .compress, presets: makeStore(), baseQuality: 0.85)
        XCTAssertFalse(pngOnly.canSave)
    }

    func testFrameToolStartsWithDefaultPreset() throws {
        let png = try writeImage("a.png", type: .png)
        let store = makeStore()
        let model = EditorModel(urls: [png], initialTool: .frame, presets: store, baseQuality: 0.85)
        XCTAssertTrue(model.plan.frameEnabled)
        XCTAssertEqual(model.selectedPresetID, store.defaultPreset.id)
        XCTAssertEqual(model.plan.frame, store.defaultPreset.style)
        XCTAssertEqual(model.originalSize, CGSize(width: 40, height: 20))
    }

    func testSaveAndDeleteUserPreset() throws {
        let png = try writeImage("a.png", type: .png)
        let model = EditorModel(urls: [png], initialTool: .frame, presets: makeStore(), baseQuality: 0.85)
        let before = model.presetList.count
        model.plan.frame.cornerRadius = 33
        model.saveCurrentFrameAsPreset(name: "Mine")
        XCTAssertEqual(model.presetList.count, before + 1)
        XCTAssertTrue(model.selectedPresetIsUser)
        model.deleteSelectedPreset()
        XCTAssertEqual(model.presetList.count, before)
        XCTAssertNil(model.selectedPresetID)
    }

    func testCropToolStartsWithInitialGeometry() throws {
        let png = try writeImage("a.png", type: .png)
        let model = EditorModel(urls: [png], initialTool: .crop, presets: makeStore(), baseQuality: 0.85)
        XCTAssertTrue(model.isCropToolActive)
        XCTAssertEqual(model.plan.crop, CropGeometry.initial(aspect: .free, imageSize: model.originalSize))
    }

    // MARK: final-fix wave

    func testEnablingFrameLaterAppliesDefaultPreset() throws {
        let png = try writeImage("a.png", type: .png)
        let store = makeStore()
        let model = EditorModel(urls: [png], initialTool: .crop, presets: store, baseQuality: 0.85)
        XCTAssertEqual(model.plan.frame, FrameStyle())
        model.setFrameEnabled(true)
        XCTAssertTrue(model.plan.frameEnabled)
        XCTAssertEqual(model.plan.frame, store.defaultPreset.style)
        XCTAssertEqual(model.selectedPresetID, store.defaultPreset.id)
    }

    func testEnablingFrameKeepsUserEditsAndDoesNotResetOnToggle() throws {
        let png = try writeImage("a.png", type: .png)
        let store = makeStore()
        let model = EditorModel(urls: [png], initialTool: .crop, presets: store, baseQuality: 0.85)
        model.plan.frame.cornerRadius = 5
        model.setFrameEnabled(true)
        XCTAssertEqual(model.plan.frame.cornerRadius, 5)
        XCTAssertNil(model.selectedPresetID)

        let other = EditorModel(urls: [png], initialTool: .crop, presets: store, baseQuality: 0.85)
        other.setFrameEnabled(true)
        other.plan.frame.cornerRadius = 7
        other.setFrameEnabled(false)
        other.setFrameEnabled(true)
        XCTAssertFalse(other.plan.frame == store.defaultPreset.style)
        XCTAssertEqual(other.plan.frame.cornerRadius, 7)
        other.setFrameEnabled(false)
        XCTAssertFalse(other.plan.frameEnabled)
    }

    func testTargetSizeModeHasNoEstimateAndBoundText() async throws {
        let jpg = try writeImage("b.jpg", type: .jpeg)
        let model = EditorModel(urls: [jpg], initialTool: .compress, presets: makeStore(), baseQuality: 0.85)
        model.plan.compress = .targetBytes(300 * 1024)
        for _ in 0..<100 where model.previewImage == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(model.previewImage)
        XCTAssertNil(model.estimatedBytes)
        XCTAssertTrue(model.sizeText.hasPrefix("JPEG · ≤ "), model.sizeText)
        model.plan.compress = .quality(0.5)
        for _ in 0..<100 where model.estimatedBytes == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertNotNil(model.estimatedBytes)
        XCTAssertTrue(model.sizeText.contains("≈"), model.sizeText)
    }

    func testTargetSizeParser() {
        XCTAssertEqual(TargetSizeParser.parse("300", fallback: 500), 300)
        XCTAssertEqual(TargetSizeParser.parse(" 3 0 0 ", fallback: 500), 300)
        XCTAssertEqual(TargetSizeParser.parse("abc", fallback: 500), 500)
        XCTAssertEqual(TargetSizeParser.parse("", fallback: 500), 500)
        XCTAssertEqual(TargetSizeParser.parse("0", fallback: 500), 500)
        XCTAssertEqual(TargetSizeParser.parse("a12b", fallback: 500), 12)
        XCTAssertEqual(TargetSizeParser.parse("99999999999999999999999", fallback: 500), 1_000_000)
        XCTAssertEqual(TargetSizeParser.parse("5000000", fallback: 500), 1_000_000)
    }

    func testPreviewsFirstReadableFile() throws {
        let bad = dir.appendingPathComponent("corrupt.png")
        try Data("not an image".utf8).write(to: bad)
        let jpg = try writeImage("good.jpg", type: .jpeg)
        let model = EditorModel(urls: [bad, jpg], initialTool: .compress, presets: makeStore(), baseQuality: 0.85)
        XCTAssertEqual(model.originalSize, CGSize(width: 40, height: 20))
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.sourceExtension, "jpg")
        XCTAssertTrue(model.canSave)

        let onlyBad = EditorModel(urls: [bad], initialTool: .compress, presets: makeStore(), baseQuality: 0.85)
        XCTAssertNotNil(onlyBad.errorMessage)
        XCTAssertFalse(onlyBad.canSave)
    }

    func testRenameSelectedUserPreset() throws {
        let png = try writeImage("a.png", type: .png)
        let model = EditorModel(urls: [png], initialTool: .frame, presets: makeStore(), baseQuality: 0.85)
        let builtInName = model.presetList.first(where: { $0.id == model.selectedPresetID })!.name
        model.renameSelectedPreset(to: "Nope")           // built-in: ignored
        XCTAssertEqual(model.presetList.first(where: { $0.id == model.selectedPresetID })!.name, builtInName)
        model.saveCurrentFrameAsPreset(name: "Mine")
        model.renameSelectedPreset(to: "Renamed")
        XCTAssertEqual(model.presetList.first(where: { $0.id == model.selectedPresetID })!.name, "Renamed")
    }
}
