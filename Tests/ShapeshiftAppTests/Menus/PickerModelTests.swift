import XCTest
import ConversionCore
@testable import ShapeshiftApp

@MainActor
final class PickerModelTests: XCTestCase {
    private func model(_ n: Int) -> PickerModel {
        PickerModel(formats: Array(FileFormat.allCases.prefix(n)), fileCount: 1)
    }

    func testFirstMoveSelectsFirstItem() {
        let m = model(8)
        m.move(.right)
        XCTAssertEqual(m.selected, 0)
    }

    func testHorizontalMovesClampAtEnds() {
        let m = model(3)
        m.selected = 0
        m.move(.left)
        XCTAssertEqual(m.selected, 0)
        m.move(.right); m.move(.right); m.move(.right)
        XCTAssertEqual(m.selected, 2)
    }

    func testVerticalMovesByColumnsAndClamps() {
        let m = model(10)
        m.selected = 1
        m.move(.down)
        XCTAssertEqual(m.selected, 5)
        m.move(.down)
        XCTAssertEqual(m.selected, 9)
        m.move(.down)
        XCTAssertEqual(m.selected, 9)
        m.move(.up)
        XCTAssertEqual(m.selected, 5)
        m.selected = 2
        m.move(.up)
        XCTAssertEqual(m.selected, 2)
    }

    func testSelectedFormat() {
        let m = model(3)
        XCTAssertNil(m.selectedFormat)
        m.selected = 1
        XCTAssertEqual(m.selectedFormat, m.formats[1])
    }
}
