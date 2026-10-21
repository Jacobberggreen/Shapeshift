import XCTest
import PDFKit
@testable import ShapeshiftApp

@MainActor
final class RedactionModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("redactmodel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeModel(pages: Int = 3) throws -> RedactionModel {
        let doc = PDFDocument()
        for i in 0..<pages {
            let image = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
                NSColor.red.setFill(); rect.fill(); return true
            }
            doc.insert(try XCTUnwrap(PDFPage(image: image)), at: i)
        }
        let url = dir.appendingPathComponent("a.pdf")
        XCTAssertTrue(doc.write(to: url))
        return RedactionModel(url: url)
    }

    func testInitialState() throws {
        let m = try makeModel()
        XCTAssertEqual(m.pageCount, 3)
        XCTAssertEqual(m.currentPage, 0)
        XCTAssertEqual(m.totalBoxes, 0)
        XCTAssertFalse(m.canSave)
    }

    func testAddClampsToUnitSquare() throws {
        let m = try makeModel()
        m.add(CGRect(x: -0.2, y: 0.5, width: 0.5, height: 0.8))
        let box = try XCTUnwrap(m.boxes[0]?.first)
        XCTAssertEqual(box.minX, 0, accuracy: 1e-9)
        XCTAssertEqual(box.maxX, 0.3, accuracy: 1e-9)
        XCTAssertEqual(box.minY, 0.5, accuracy: 1e-9)
        XCTAssertEqual(box.maxY, 1, accuracy: 1e-9)
        XCTAssertTrue(m.canSave)
    }

    func testTinyBoxesIgnored() throws {
        let m = try makeModel()
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.004, height: 0.3))
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.004))
        m.add(CGRect(x: 2, y: 2, width: 0.3, height: 0.3))   // clamps to nothing
        XCTAssertEqual(m.totalBoxes, 0)
    }

    func testUndoRemoveAndClear() throws {
        let m = try makeModel()
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        m.add(CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2))
        m.undoLast()
        XCTAssertEqual(m.boxes[0]?.count, 1)
        m.undoLast()
        XCTAssertNil(m.boxes[0])
        m.undoLast()   // no-op on empty
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        m.add(CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2))
        m.remove(at: 0)
        XCTAssertEqual(m.boxes[0]?.first?.minX ?? 0, 0.5, accuracy: 1e-9)
        m.remove(at: 5)   // out of range ignored
        m.clearPage()
        XCTAssertEqual(m.totalBoxes, 0)
        XCTAssertNil(m.boxes[0])
    }

    func testCountsAcrossPages() throws {
        let m = try makeModel()
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        m.add(CGRect(x: 0.4, y: 0.1, width: 0.2, height: 0.2))
        m.next()
        m.add(CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
        XCTAssertEqual(m.totalBoxes, 3)
        XCTAssertEqual(m.pagesAffected, 2)
        m.clearPage()
        XCTAssertEqual(m.pagesAffected, 1)
    }

    func testPagingBounds() throws {
        let m = try makeModel()
        m.previous()
        XCTAssertEqual(m.currentPage, 0)
        m.next(); m.next(); m.next()
        XCTAssertEqual(m.currentPage, 2)
        m.previous()
        XCTAssertEqual(m.currentPage, 1)
    }

    func testPreviewCached() throws {
        let m = try makeModel()
        let a = try XCTUnwrap(m.preview(for: 0))
        let b = try XCTUnwrap(m.preview(for: 0))
        XCTAssertTrue(a === b)
        XCTAssertNil(m.preview(for: 9))
    }
}
