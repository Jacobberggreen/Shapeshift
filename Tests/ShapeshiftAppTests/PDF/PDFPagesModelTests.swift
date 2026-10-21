import XCTest
import PDFKit
@testable import ShapeshiftApp
import ConversionCore

@MainActor
final class PDFPagesModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pagesmodel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeModel(pages: Int) throws -> PDFPagesModel {
        let doc = PDFDocument()
        for i in 0..<pages {
            let image = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
                NSColor.red.setFill(); rect.fill(); return true
            }
            doc.insert(try XCTUnwrap(PDFPage(image: image)), at: i)
        }
        let url = dir.appendingPathComponent("a.pdf")
        XCTAssertTrue(doc.write(to: url))
        return PDFPagesModel(url: url)
    }

    private func order(_ model: PDFPagesModel) -> [Int] { model.pages.map(\.sourceIndex) }

    func testInitialIdentityAndNotModified() throws {
        let m = try makeModel(pages: 3)
        XCTAssertEqual(order(m), [0, 1, 2])
        XCTAssertFalse(m.isModified)
        XCTAssertTrue(m.canSave)
    }

    func testMoveBeforeTarget() throws {
        let m = try makeModel(pages: 4)
        m.move(from: 0, to: 3)       // before card 3 -> 1,2,0,3
        XCTAssertEqual(order(m), [1, 2, 0, 3])
        m.move(from: 3, to: 0)       // before card 0 -> 3,1,2,0
        XCTAssertEqual(order(m), [3, 1, 2, 0])
        m.move(from: 1, to: 4)       // to the end
        XCTAssertEqual(order(m), [3, 2, 0, 1])
        XCTAssertTrue(m.isModified)
    }

    func testMoveOntoSelfOrNextIsNoOp() throws {
        let m = try makeModel(pages: 3)
        m.move(from: 1, to: 1)
        m.move(from: 1, to: 2)
        m.move(from: 9, to: 0)
        XCTAssertEqual(order(m), [0, 1, 2])
        XCTAssertFalse(m.isModified)
    }

    func testRotateNormalisesThroughEdits() throws {
        let m = try makeModel(pages: 2)
        m.rotate(at: 0, by: -90)
        XCTAssertEqual(m.edits[0].rotation, 270)
        m.rotate(at: 0, by: 90)
        XCTAssertEqual(m.edits[0].rotation, 0)
        XCTAssertFalse(m.isModified)
        for _ in 0..<5 { m.rotate(at: 1, by: 90) }
        XCTAssertEqual(m.edits[1].rotation, 90)
        XCTAssertTrue(m.isModified)
    }

    func testDeleteAndCanSave() throws {
        let m = try makeModel(pages: 2)
        m.delete(at: 0)
        XCTAssertEqual(order(m), [1])
        XCTAssertTrue(m.isModified)
        XCTAssertTrue(m.canSave)
        m.delete(at: 0)
        XCTAssertFalse(m.canSave)
        m.delete(at: 5)
    }

    func testEditsFeedRebuild() throws {
        let m = try makeModel(pages: 3)
        m.move(from: 2, to: 0)
        m.rotate(at: 0, by: 90)
        m.delete(at: 2)
        let doc = try PDFOperations.rebuild(try XCTUnwrap(PDFDocument(url: m.url)), edits: m.edits)
        XCTAssertEqual(doc.pageCount, 2)
        XCTAssertEqual(doc.page(at: 0)?.rotation, 90)
    }

    func testThumbnailCached() throws {
        let m = try makeModel(pages: 2)
        let a = m.thumbnail(forSource: 0)
        XCTAssertNotNil(a)
        XCTAssertTrue(a === m.thumbnail(forSource: 0))
        XCTAssertNil(m.thumbnail(forSource: 9))
    }
}
