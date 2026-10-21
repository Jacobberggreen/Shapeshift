import XCTest
@testable import EditCore

final class CropStepTests: XCTestCase {
    private let ctx = EditContext(scale: 1, referenceLongSide: 100)

    func testCropsTopRightQuadrant() throws {
        let img = quadrantImage(width: 100, height: 100)
        let out = try CropStep(rect: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5)).apply(to: img, context: ctx)
        XCTAssertEqual(out.width, 50); XCTAssertEqual(out.height, 50)
        XCTAssertTrue(isClose(pixel(out, x: 25, y: 25), 0, 255, 0))      // green
    }

    func testCropsBottomLeftQuadrant() throws {
        let img = quadrantImage(width: 100, height: 100)
        let out = try CropStep(rect: NormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5)).apply(to: img, context: ctx)
        XCTAssertTrue(isClose(pixel(out, x: 25, y: 25), 0, 0, 255))      // blue
    }

    func testFullRectIsIdentitySize() throws {
        let img = quadrantImage(width: 64, height: 32)
        let out = try CropStep(rect: .full).apply(to: img, context: ctx)
        XCTAssertEqual(out.width, 64); XCTAssertEqual(out.height, 32)
    }

    func testSameNormalizedRectWorksOnDifferentSizes() throws {
        let step = CropStep(rect: NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        let small = try step.apply(to: solidImage(width: 40, height: 40), context: ctx)
        let big = try step.apply(to: solidImage(width: 400, height: 200), context: ctx)
        XCTAssertEqual(small.width, 20); XCTAssertEqual(small.height, 20)
        XCTAssertEqual(big.width, 200); XCTAssertEqual(big.height, 100)
    }
}
