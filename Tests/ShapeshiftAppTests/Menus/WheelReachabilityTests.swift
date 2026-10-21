import XCTest
import ConversionCore
@testable import ShapeshiftApp

final class WheelReachabilityTests: XCTestCase {
    private func formats(_ n: Int) -> [FileFormat] { (0..<n).map { FileFormat.allCases[$0 % FileFormat.allCases.count] } }
    private let moves: [PickerMove] = [.left, .right, .up, .down]

    private func assertAllReachable(_ items: [WheelItem], _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let start = WheelNavigator.next(from: nil, direction: .down, items: items) else {
            XCTAssertTrue(items.isEmpty, "\(label): no start item", file: file, line: line)
            return
        }
        var seen: Set<Int> = [start]
        var queue = [start]
        while let current = queue.popLast() {
            for move in moves {
                if let n = WheelNavigator.next(from: current, direction: move, items: items), seen.insert(n).inserted {
                    queue.append(n)
                }
            }
        }
        let missing = items.indices.filter { !seen.contains($0) }
        XCTAssertTrue(missing.isEmpty, "\(label): unreachable items \(missing)", file: file, line: line)
    }

    func testEveryItemIsReachableByArrowKeys() {
        let tools = EditTool.allCases.map(ToolKind.image)
        for (f, t) in [(6, 4), (14, 4), (3, 4), (6, 0), (0, 4)] {
            assertAllReachable(WheelLayout.items(style: .twoRings, step: .root, formats: formats(f), tools: Array(tools.prefix(t))), "twoRings \(f)/\(t)")
        }
        for (f, t) in [(6, 4), (14, 4), (6, 0), (0, 4), (12, 0)] {
            assertAllReachable(WheelLayout.items(style: .splitRing, step: .root, formats: formats(f), tools: Array(tools.prefix(t))), "splitRing \(f)/\(t)")
        }
        for n in [6, 14] {
            assertAllReachable(WheelLayout.items(style: .twoSteps, step: .category(.convert), formats: formats(n), tools: tools), "convert \(n)")
        }
        assertAllReachable(WheelLayout.items(style: .twoSteps, step: .category(.tools), formats: formats(6), tools: tools), "tools")
        assertAllReachable(WheelLayout.items(style: .twoSteps, step: .root, formats: formats(6), tools: tools), "root")
    }
}
