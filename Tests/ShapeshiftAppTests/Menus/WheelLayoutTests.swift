import XCTest
import ConversionCore
@testable import ShapeshiftApp

final class WheelLayoutTests: XCTestCase {
    private func formats(_ n: Int) -> [FileFormat] { (0..<n).map { FileFormat.allCases[$0 % FileFormat.allCases.count] } }
    private let tools = EditTool.allCases.map(ToolKind.image)
    private let tau = 2 * CGFloat.pi

    private func width(_ s: WheelSector) -> CGFloat { (s.endAngle - s.startAngle) * s.midRadius - WheelLayout.gap }

    func testEverySliceIsWideEnough() {
        for style in [MenuStyle.twoRings, .splitRing, .twoSteps] {
            for count in [3, 6, 14, 20] {
                let steps: [WheelStep] = style == .twoSteps ? [.category(.convert), .category(.tools)] : [.root]
                for step in steps {
                    for item in WheelLayout.items(style: style, step: step, formats: formats(count), tools: tools) {
                        XCTAssertGreaterThanOrEqual(width(item.sector), WheelLayout.minArc - 0.5, "\(style) \(count)")
                    }
                }
            }
        }
    }

    func testTwoRingsPutsToolsInsideFormatsWithAGap() {
        let items = WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: tools)
        XCTAssertEqual(items.count, 10)
        let formatItems = items.prefix(6), toolItems = items.suffix(4)
        let toolsOuter = toolItems.map(\.sector.outerRadius).max()!
        let formatsInner = formatItems.map(\.sector.innerRadius).min()!
        XCTAssertGreaterThanOrEqual(formatsInner, toolsOuter + WheelLayout.gap - 0.01)
        XCTAssertGreaterThanOrEqual(toolItems.map(\.sector.innerRadius).min()!, WheelLayout.firstInnerRadius - 0.01)
        XCTAssertEqual(items.map(\.id), Array(0..<10))
    }

    func testFirstSliceIsCentredAtTheTopAndRunsClockwise() {
        let items = WheelLayout.items(style: .twoRings, step: .root, formats: formats(6), tools: [])
        XCTAssertEqual(items[0].offset.x, 0, accuracy: 0.5)
        XCTAssertLessThan(items[0].offset.y, 0)
        XCTAssertGreaterThan(items[1].offset.x, 0)
    }

    func testSlicesInOneRingNeverOverlapAngularly() {
        for style in [MenuStyle.twoRings, .splitRing] {
            let items = WheelLayout.items(style: style, step: .root, formats: formats(10), tools: tools)
            for i in items.indices {
                for j in items.indices where j > i && abs(items[i].sector.innerRadius - items[j].sector.innerRadius) < 0.01 {
                    let a = items[i].sector, b = items[j].sector
                    XCTAssertTrue(a.endAngle <= b.startAngle + 0.0001 || b.endAngle <= a.startAngle + 0.0001, "\(style) \(i) \(j)")
                }
            }
        }
    }

    func testSplitRingGroupsFormatsAndToolsWithAnEmptySlot() {
        let items = WheelLayout.items(style: .splitRing, step: .root, formats: formats(5), tools: tools)
        XCTAssertEqual(items.count, 9)
        XCTAssertEqual(items[2].offset.x, 0, accuracy: 0.5)                       // middle of 5 formats is at the top
        XCTAssertLessThan(items[2].offset.y, 0)
        let step = items[1].sector.startAngle - items[0].sector.startAngle
        let gap = items[5].sector.startAngle - items[4].sector.endAngle
        XCTAssertEqual(gap, step, accuracy: 0.0001)                                // one empty slot between the groups
        XCTAssertEqual(Set(items.map(\.sector.innerRadius)).count, 1)              // a single ring
    }

    func testTwoStepsRootIsTwoHalves() {
        let root = WheelLayout.items(style: .twoSteps, step: .root, formats: formats(6), tools: tools)
        XCTAssertEqual(root.map(\.entry), [.category(.convert), .category(.tools)])
        XCTAssertEqual(root[0].sector.startAngle, -.pi, accuracy: 0.0001)
        XCTAssertEqual(root[0].sector.endAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(root[1].sector.startAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(root[1].sector.endAngle, .pi, accuracy: 0.0001)
        XCTAssertLessThan(root[0].offset.x, 0)
        XCTAssertGreaterThan(root[1].offset.x, 0)
    }

    func testTwoStepsCategoryStepsAreSingleRings() {
        let convert = WheelLayout.items(style: .twoSteps, step: .category(.convert), formats: formats(6), tools: tools)
        XCTAssertEqual(convert.count, 6)
        XCTAssertEqual(Set(convert.map(\.sector.innerRadius)).count, 1)
        let toolRing = WheelLayout.items(style: .twoSteps, step: .category(.tools), formats: formats(6), tools: tools)
        XCTAssertEqual(toolRing.map(\.entry), tools.map { .action(.tool($0)) })
    }

    func testRingsGrowWithManyFormats() {
        let few = WheelLayout.items(style: .splitRing, step: .root, formats: formats(4), tools: [])
        let many = WheelLayout.items(style: .splitRing, step: .root, formats: formats(20), tools: [])
        XCTAssertGreaterThan(many[0].sector.innerRadius, few[0].sector.innerRadius)
    }

    func testClassicGridAndEmptyInputGiveNoItems() {
        XCTAssertEqual(WheelLayout.items(style: .classicGrid, step: .root, formats: formats(6), tools: tools), [])
        for style in [MenuStyle.twoRings, .splitRing, .twoSteps] {
            XCTAssertEqual(WheelLayout.items(style: style, step: .root, formats: [], tools: []), [])
        }
    }

    func testPanelSizeCoversEveryStep() {
        for style in [MenuStyle.twoRings, .splitRing, .twoSteps] {
            let size = WheelLayout.panelSize(style: style, formats: formats(14), tools: tools)
            XCTAssertEqual(size.width, size.height)
            let steps: [WheelStep] = style == .twoSteps ? [.root, .category(.convert), .category(.tools)] : [.root]
            for step in steps {
                for item in WheelLayout.items(style: style, step: step, formats: formats(14), tools: tools) {
                    XCTAssertLessThanOrEqual(item.sector.outerRadius + WheelLayout.margin, size.width / 2 + 0.01)
                }
            }
        }
    }
}
