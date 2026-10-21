import XCTest
import ConversionCore
@testable import ShapeshiftApp

@MainActor
final class ActionPickerModelTests: XCTestCase {
    private func model(formats: Int, tools: [ToolKind] = EditTool.allCases.map(ToolKind.image)) -> ActionPickerModel {
        ActionPickerModel(formats: Array(FileFormat.allCases.prefix(formats)), tools: tools, fileCount: 1)
    }

    func testFirstMoveSelectsFirstItem() {
        let m = model(formats: 6)
        m.move(.down)
        XCTAssertEqual(m.selected, 0)
    }

    func testEmptyModelNeverSelects() {
        let m = model(formats: 0, tools: [])
        m.move(.right)
        XCTAssertNil(m.selected)
        XCTAssertNil(m.selectedAction)
    }

    func testLeftRightWalkThroughFormatsThenTools() {
        let m = model(formats: 2)          // indices 0,1 formats; 2...5 tools
        m.selected = 1
        m.move(.right)
        XCTAssertEqual(m.selected, 2)
        XCTAssertEqual(m.selectedAction, .tool(.image(.frame)))
        m.selected = 5
        m.move(.right)
        XCTAssertEqual(m.selected, 5)
        m.selected = 0
        m.move(.left)
        XCTAssertEqual(m.selected, 0)
    }

    func testDownWithinFormatGrid() {
        let m = model(formats: 10)
        m.selected = 1
        m.move(.down)
        XCTAssertEqual(m.selected, 5)
    }

    func testDownIntoPartialLastRowClampsToLastFormat() {
        let m = model(formats: 6)          // rows: 0-3, 4-5
        m.selected = 3
        m.move(.down)
        XCTAssertEqual(m.selected, 5)
    }

    func testDownFromLastFormatRowGoesToToolInSameColumn() {
        let m = model(formats: 6)
        m.selected = 5                      // column 1
        m.move(.down)
        XCTAssertEqual(m.selected, 6 + 1)
        XCTAssertEqual(m.selectedAction, .tool(.image(.crop)))
    }

    func testDownFromLastFormatRowClampsColumnToToolCount() {
        let m = model(formats: 4, tools: [.image(.frame), .image(.crop)])
        m.selected = 3                      // column 3, only 2 tools
        m.move(.down)
        XCTAssertEqual(m.selected, 4 + 1)
    }

    func testDownFromLastFormatRowWithoutToolsStays() {
        let m = model(formats: 6, tools: [])
        m.selected = 5
        m.move(.down)
        XCTAssertEqual(m.selected, 5)
    }

    func testDownFromToolsStays() {
        let m = model(formats: 4)
        m.selected = 4 + 2
        m.move(.down)
        XCTAssertEqual(m.selected, 6)
    }

    func testUpFromToolGoesToLastFormatRowSameColumn() {
        let m = model(formats: 6)          // last row starts at 4
        m.selected = 6 + 1                  // tool column 1
        m.move(.up)
        XCTAssertEqual(m.selected, 5)
        m.selected = 6 + 3                  // tool column 3 → 4+3=7 clamps to 5
        m.move(.up)
        XCTAssertEqual(m.selected, 5)
    }

    func testUpFromFirstFormatRowStaysAndUpWithinGrid() {
        let m = model(formats: 10)
        m.selected = 2
        m.move(.up)
        XCTAssertEqual(m.selected, 2)
        m.selected = 6
        m.move(.up)
        XCTAssertEqual(m.selected, 2)
    }

    func testToolsOnlyModelUpAndDown() {
        let m = model(formats: 0)
        m.selected = 1
        m.move(.up)
        XCTAssertEqual(m.selected, 1)
        m.move(.down)
        XCTAssertEqual(m.selected, 1)
    }

    func testHandleKeyMapsArrowsReturnEscape() {
        let m = model(formats: 3)
        XCTAssertEqual(m.handle(keyCode: 124), .handled)
        XCTAssertEqual(m.selected, 0)
        XCTAssertEqual(m.handle(keyCode: 124), .handled)
        XCTAssertEqual(m.selected, 1)
        XCTAssertEqual(m.handle(keyCode: 123), .handled)
        XCTAssertEqual(m.selected, 0)
        XCTAssertEqual(m.handle(keyCode: 36), .choose(.format(FileFormat.allCases[0])))
        XCTAssertEqual(m.handle(keyCode: 76), .choose(.format(FileFormat.allCases[0])))
        XCTAssertEqual(m.handle(keyCode: 53), .close)
        XCTAssertEqual(m.handle(keyCode: 0), .ignored)
    }

    func testReturnWithoutSelectionIsHandledNotChosen() {
        let m = model(formats: 3)
        XCTAssertEqual(m.handle(keyCode: 36), .handled)
    }
}
