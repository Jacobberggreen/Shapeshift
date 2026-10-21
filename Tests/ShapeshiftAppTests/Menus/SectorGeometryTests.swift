import XCTest
@testable import ShapeshiftApp

final class SectorGeometryTests: XCTestCase {
    private let sector = WheelSector(innerRadius: 80, outerRadius: 150, startAngle: 0, endAngle: .pi / 2)

    private func contains(_ polygon: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private var outline: [CGPoint] { SectorGeometry.outline(sector: sector, gap: 6, cornerRadius: 9) }

    func testCentroidIsInsideAndMatchesPolarMidpoint() {
        XCTAssertTrue(contains(outline, sector.centroid))
        let expected = SectorGeometry.polar(115, .pi / 4)
        XCTAssertEqual(sector.centroid.x, expected.x, accuracy: 0.001)
        XCTAssertEqual(sector.centroid.y, expected.y, accuracy: 0.001)
    }

    func testPointsOnTheTrueBoundaryAreInTheGap() {
        XCTAssertFalse(contains(outline, SectorGeometry.polar(115, 0)))           // start boundary
        XCTAssertFalse(contains(outline, SectorGeometry.polar(115, .pi / 2)))     // end boundary
    }

    func testGapIsAConstantWidthNotAConstantAngle() {
        // 4 pt inside the boundary (more than gap/2 = 3) is in; 2 pt inside is out — at inner and at outer radius.
        for radius in [95.0, 135.0] as [CGFloat] {
            let a = SectorGeometry.polar(radius, asin(4 / radius))
            let b = SectorGeometry.polar(radius, asin(2 / radius))
            XCTAssertTrue(contains(outline, a), "radius \(radius)")
            XCTAssertFalse(contains(outline, b), "radius \(radius)")
        }
    }

    func testCornersAreRounded() {
        // The sharp outer-start corner is where the offset edge meets the outer circle.
        let sharp = SectorGeometry.polar(149.5, asin(3 / 149.5) + 0.002)
        XCTAssertFalse(contains(outline, sharp))
        XCTAssertTrue(contains(outline, SectorGeometry.polar(140, asin(3 / 140) + 0.1)))
    }

    func testOutlineStaysBetweenTheRadii() {
        for p in outline {
            let r = hypot(p.x, p.y)
            XCTAssertLessThanOrEqual(r, 150.01)
            XCTAssertGreaterThanOrEqual(r, 79.99)
        }
    }

    func testFullHalfRingSectorHasNoSelfCrossingAndPositiveArea() {
        let half = WheelSector(innerRadius: 78, outerRadius: 142, startAngle: -.pi, endAngle: 0)
        let points = SectorGeometry.outline(sector: half, gap: 6, cornerRadius: 9)
        var area: CGFloat = 0
        for i in points.indices { let a = points[i], b = points[(i + 1) % points.count]; area += a.x * b.y - b.x * a.y }
        XCTAssertGreaterThan(abs(area / 2), 1000)
        XCTAssertTrue(contains(points, half.centroid))
    }
}
