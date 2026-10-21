import XCTest
@testable import ShapeshiftApp

@MainActor
final class ToolPickerTests: XCTestCase {
    func testFirstMoveSelectsFirstTool() {
        let m = ToolPickerModel(tools: EditTool.allCases.map(ToolKind.image), fileCount: 1)
        XCTAssertNil(m.selectedTool)
        m.move(.right)
        XCTAssertEqual(m.selectedTool, .image(.frame))
    }

    func testMovesClampAtBothEnds() {
        let m = ToolPickerModel(tools: EditTool.allCases.map(ToolKind.image), fileCount: 1)
        m.selected = 0
        m.move(.left); XCTAssertEqual(m.selected, 0)
        m.move(.up); XCTAssertEqual(m.selected, 0)
        m.move(.right); m.move(.right); m.move(.right); m.move(.right); m.move(.down)
        XCTAssertEqual(m.selected, 3)
        XCTAssertEqual(m.selectedTool, .image(.stripMetadata))
    }
}
