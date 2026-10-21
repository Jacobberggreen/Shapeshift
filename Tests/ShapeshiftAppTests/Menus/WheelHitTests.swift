import XCTest
import ConversionCore
@testable import ShapeshiftApp

final class WheelHitTests: XCTestCase {
    private func formats(_ n: Int) -> [FileFormat] { (0..<n).map { FileFormat.allCases[$0 % FileFormat.allCases.count] } }
    private let tools = EditTool.allCases.map(ToolKind.image)

    private func configurations() -> [(String, [WheelItem])] {
        [
            ("twoRings 6/4", WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: tools)),
            ("twoRings 12/4", WheelLayout.items(style: .twoRings, step: .root, formats: formats(12), tools: tools)),
            ("twoRings 6/0", WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: [])),
            ("splitRing 14/4", WheelLayout.items(style: .splitRing, step: .root, formats: formats(14), tools: tools)),
            ("splitRing 0/4", WheelLayout.items(style: .splitRing, step: .root, formats: [], tools: tools)),
            ("twoSteps root", WheelLayout.items(style: .twoSteps, step: .root, formats: formats(6), tools: tools)),
            ("twoSteps convert", WheelLayout.items(style: .twoSteps, step: .category(.convert), formats: formats(6), tools: tools)),
            ("twoSteps tools", WheelLayout.items(style: .twoSteps, step: .category(.tools), formats: formats(6), tools: tools)),
        ]
    }

    func testEveryCentroidHitsItsOwnSlice() {
        for (name, items) in configurations() {
            for (index, item) in items.enumerated() {
                XCTAssertEqual(WheelLayout.item(at: item.offset, in: items), index, "\(name) slice \(index)")
            }
        }
    }

    func testPointsNearTheSliceEdgesStayInThatSlice() {
        for (name, items) in configurations() {
            for (index, item) in items.enumerated() {
                let s = item.sector
                let radius = s.midRadius
                // 3 pt inside each side edge, along the mid radius
                let inset = 3 / radius
                for angle in [s.startAngle + inset, s.endAngle - inset] {
                    let p = SectorGeometry.polar(radius, angle)
                    XCTAssertEqual(WheelLayout.item(at: p, in: items), index, "\(name) slice \(index)")
                }
                // 3 pt inside the inner and outer radius, at mid angle
                for r in [s.innerRadius + 3, s.outerRadius - 3] {
                    let p = SectorGeometry.polar(r, s.midAngle)
                    XCTAssertEqual(WheelLayout.item(at: p, in: items), index, "\(name) slice \(index) r=\(r)")
                }
            }
        }
    }

    func testGapsBetweenNeighboursBelongToASlice() {
        for (name, items) in configurations() where items.count > 2 {
            let s = items[0].sector
            let boundary = SectorGeometry.polar(s.midRadius, s.endAngle)   // exactly on the shared boundary
            XCTAssertNotNil(WheelLayout.item(at: boundary, in: items), name)
        }
    }

    func testHubAndOutsideReturnNil() {
        for (name, items) in configurations() {
            XCTAssertNil(WheelLayout.item(at: .zero, in: items), name)
            let innermost = items.map(\.sector.innerRadius).min()!
            XCTAssertNil(WheelLayout.item(at: SectorGeometry.polar(innermost - 10, 0.3), in: items), name)
            let outermost = items.map(\.sector.outerRadius).max()!
            XCTAssertNil(WheelLayout.item(at: SectorGeometry.polar(outermost + 10, 0.3), in: items), name)
        }
    }

    func testTwoRingsGapBetweenRingsStillHitsARing() {
        let items = WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: tools)
        let toolsOuter = items.suffix(4).map(\.sector.outerRadius).max()!
        let p = SectorGeometry.polar(toolsOuter + WheelLayout.gap / 2, 0.2)
        XCTAssertNotNil(WheelLayout.item(at: p, in: items))
    }

    func testSliceCrossingTheTopMatchesOnBothSides() {
        let items = WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: [])
        let r = items[0].sector.midRadius
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: -4, y: -r), in: items), 0)    // just left of the top
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: 4, y: -r), in: items), 0)     // just right of the top
    }

    func testTwoStepsRootLeftIsConvertAndRightIsTools() {
        let items = WheelLayout.items(style: .twoSteps, step: .root, formats: formats(6), tools: tools)
        let r = items[0].sector.midRadius
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: -r, y: 0), in: items), 0)
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: r, y: 0), in: items), 1)
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: 0, y: -r), in: items) != nil, true)
        XCTAssertEqual(WheelLayout.item(at: CGPoint(x: 0, y: r), in: items) != nil, true)
    }

    func testEmptyItemsHitNothing() {
        XCTAssertNil(WheelLayout.item(at: CGPoint(x: 100, y: 0), in: []))
    }
}
