import XCTest
@testable import ConversionCore

final class OutputPlannerTests: XCTestCase {
    func testSiblingUsesNewExtension() {
        let dir = TemporaryDirectory()
        let out = OutputPlanner.uniqueSibling(of: dir.file("photo.png"), format: .jpeg)
        XCTAssertEqual(out, dir.file("photo.jpg"))
    }

    func testCollisionAddsCounter() throws {
        let dir = TemporaryDirectory()
        try Data().write(to: dir.file("photo.jpg"))
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), format: .jpeg), dir.file("photo 2.jpg"))
        try Data().write(to: dir.file("photo 2.jpg"))
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), format: .jpeg), dir.file("photo 3.jpg"))
    }

    func testTemporarySiblingIsHiddenSameDirectoryAndKeepsExtension() {
        let final = URL(fileURLWithPath: "/tmp/x/photo.jpg")
        let tmp = OutputPlanner.temporarySibling(for: final)
        XCTAssertEqual(tmp.deletingLastPathComponent(), final.deletingLastPathComponent())
        XCTAssertTrue(tmp.lastPathComponent.hasPrefix(".shapeshift-"))
        XCTAssertEqual(tmp.pathExtension, "jpg")
    }

    func testQualityIsClamped() {
        XCTAssertEqual(ConversionOptions(quality: 3).quality, 1)
        XCTAssertEqual(ConversionOptions(quality: -1).quality, 0)
        XCTAssertEqual(ConversionOptions().quality, 0.85)
    }
}
