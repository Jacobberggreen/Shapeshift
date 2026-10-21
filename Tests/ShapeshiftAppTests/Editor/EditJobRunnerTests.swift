import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ConversionCore
import EditCore
@testable import ShapeshiftApp

private final class Dir {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("shapeshift-runner-\(UUID().uuidString)")
    init() { try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
    deinit { try? FileManager.default.removeItem(at: url) }
}

private func writePNG(_ url: URL, width: Int = 80, height: Int = 60) {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest))
}

final class EditJobRunnerTests: XCTestCase {
    private func framePlan() -> EditorPlan {
        var plan = EditorPlan(); plan.frameEnabled = true; plan.frame.margin = 5
        return plan
    }

    func testWritesLabelledSiblingAndLeavesOriginalUntouched() async throws {
        let dir = Dir(); let src = dir.file("pic.png"); writePNG(src)
        let before = try Data(contentsOf: src)
        let results = await EditJobRunner().run(inputs: [src], plan: framePlan())
        let out = try results[0].result.get()
        XCTAssertEqual(out, dir.file("pic framed.png"))
        XCTAssertEqual(try Data(contentsOf: src), before)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }

    func testSecondRunDoesNotOverwrite() async throws {
        let dir = Dir(); let src = dir.file("pic.png"); writePNG(src)
        _ = await EditJobRunner().run(inputs: [src], plan: framePlan())
        let second = await EditJobRunner().run(inputs: [src], plan: framePlan())
        XCTAssertEqual(try second[0].result.get(), dir.file("pic framed 2.png"))
    }

    func testBatchContinuesAfterAFailureAndLeavesNoTempFiles() async throws {
        let dir = Dir()
        let good1 = dir.file("a.png"), bad = dir.file("b.png"), good2 = dir.file("c.png")
        writePNG(good1); writePNG(good2); try Data("junk".utf8).write(to: bad)
        let results = await EditJobRunner().run(inputs: [good1, bad, good2], plan: framePlan())
        XCTAssertNoThrow(try results[0].result.get())
        XCTAssertThrowsError(try results[1].result.get())
        XCTAssertNoThrow(try results[2].result.get())
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
        XCTAssertFalse(names.contains { $0.hasPrefix(".shapeshift-") })
    }

    func testPlanWithNoWorkForAFileIsReportedAsFailure() async throws {
        let dir = Dir(); let src = dir.file("pic.png"); writePNG(src)
        var plan = EditorPlan(); plan.compressEnabled = true            // nothing applicable to a PNG
        let results = await EditJobRunner().run(inputs: [src], plan: plan)
        XCTAssertThrowsError(try results[0].result.get())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.url.path), ["pic.png"])
    }

    func testCancelledRunReportsCancelledAndWritesNothing() async throws {
        let dir = Dir(); let src = dir.file("pic.png"); writePNG(src)
        let task = Task { () -> [ConversionResult] in
            try? await Task.sleep(nanoseconds: 200_000_000)               // cancelled while sleeping
            return await EditJobRunner().run(inputs: [src], plan: self.framePlan())
        }
        task.cancel()
        let results = await task.value
        guard case .failure(.cancelled) = results[0].result else { return XCTFail("expected cancelled") }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.url.path), ["pic.png"])
    }
}
