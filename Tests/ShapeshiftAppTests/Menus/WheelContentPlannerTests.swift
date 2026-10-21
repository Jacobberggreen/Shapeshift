import XCTest
import ConversionCore
@testable import ShapeshiftApp

final class WheelContentPlannerTests: XCTestCase {
    private let formats = [FileFormat.png, .jpeg, .heic]
    private let tools = EditTool.allCases.map(ToolKind.image)

    func testTwoRingsShowsFormatsAndToolsForBothTriggers() {
        for style in [MenuStyle.twoRings, .splitRing] {
            for intent in [DragIntent.convert, .tools] {
                XCTAssertEqual(WheelContentPlanner.plan(style: style, intent: intent, formats: formats, tools: tools),
                               WheelContent(formats: formats, tools: tools), "\(style) \(intent)")
            }
        }
    }

    func testCombinedStylesShowOnlyFormatsForNonImages() {
        for intent in [DragIntent.convert, .tools] {
            XCTAssertEqual(WheelContentPlanner.plan(style: .twoRings, intent: intent, formats: [.mp3, .wav], tools: []),
                           WheelContent(formats: [.mp3, .wav], tools: []))
        }
    }

    func testCombinedStylesCanShowToolsOnlyWhenNoFormatsExist() {
        XCTAssertEqual(WheelContentPlanner.plan(style: .splitRing, intent: .convert, formats: [], tools: tools),
                       WheelContent(formats: [], tools: tools))
        XCTAssertNil(WheelContentPlanner.plan(style: .splitRing, intent: .convert, formats: [], tools: []))
    }

    func testTwoStepsKeepsOneKindPerTrigger() {
        XCTAssertEqual(WheelContentPlanner.plan(style: .twoSteps, intent: .convert, formats: formats, tools: tools),
                       WheelContent(formats: formats, tools: []))
        XCTAssertEqual(WheelContentPlanner.plan(style: .twoSteps, intent: .tools, formats: formats, tools: tools),
                       WheelContent(formats: [], tools: tools))
        XCTAssertNil(WheelContentPlanner.plan(style: .twoSteps, intent: .tools, formats: formats, tools: []))
        XCTAssertNil(WheelContentPlanner.plan(style: .twoSteps, intent: .convert, formats: [], tools: tools))
    }

    func testClassicGridIsNotAWheel() {
        XCTAssertNil(WheelContentPlanner.plan(style: .classicGrid, intent: .convert, formats: formats, tools: tools))
    }
}
