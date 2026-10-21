import XCTest
@testable import ShapeshiftApp

final class WheelNavigatorTests: XCTestCase {
    private func item(_ id: Int, _ x: CGFloat, _ y: CGFloat) -> WheelItem {
        let radius = hypot(x, y), angle = atan2(x, -y)
        return WheelItem(id: id, entry: .action(.tool(.image(.frame))),
                         sector: WheelSector(innerRadius: radius - 1, outerRadius: radius + 1,
                                             startAngle: angle - 0.01, endAngle: angle + 0.01))
    }

    func testFirstArrowSelectsTheTopmostItem() {
        let items = [item(0, 100, 0), item(1, 0, -100), item(2, 0, 100)]
        XCTAssertEqual(WheelNavigator.next(from: nil, direction: .right, items: items), 1)
    }

    func testMovesAlongARow() {
        let items = [item(0, -60, 0), item(1, 0, 0), item(2, 60, 0)]
        XCTAssertEqual(WheelNavigator.next(from: 0, direction: .right, items: items), 1)
        XCTAssertEqual(WheelNavigator.next(from: 1, direction: .right, items: items), 2)
        XCTAssertEqual(WheelNavigator.next(from: 2, direction: .left, items: items), 1)
    }

    func testStaysWhenNothingLiesThatWay() {
        let items = [item(0, -60, 0), item(1, 0, 0), item(2, 60, 0)]
        XCTAssertNil(WheelNavigator.next(from: 2, direction: .right, items: items))
        XCTAssertNil(WheelNavigator.next(from: 1, direction: .up, items: items))
    }

    func testWalksAroundARing() {
        // A top, B right, C bottom, D left
        let items = [item(0, 0, -100), item(1, 100, 0), item(2, 0, 100), item(3, -100, 0)]
        XCTAssertEqual(WheelNavigator.next(from: 0, direction: .right, items: items), 1)
        XCTAssertEqual(WheelNavigator.next(from: 0, direction: .down, items: items), 2)   // straight across wins over the diagonals
        XCTAssertEqual(WheelNavigator.next(from: 1, direction: .down, items: items), 2)
        XCTAssertEqual(WheelNavigator.next(from: 3, direction: .up, items: items), 0)
    }

    func testEmptyAndSingleItem() {
        XCTAssertNil(WheelNavigator.next(from: nil, direction: .up, items: []))
        XCTAssertNil(WheelNavigator.next(from: 0, direction: .up, items: [item(0, 0, 0)]))
    }

    func testIgnoresAStaleIndex() {
        let items = [item(0, 0, -100), item(1, 0, 100)]
        XCTAssertEqual(WheelNavigator.next(from: 7, direction: .down, items: items), 0)   // treated as "no selection"
    }
}
