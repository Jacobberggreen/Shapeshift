import XCTest
import PDFKit
@testable import ShapeshiftApp

@MainActor
final class PDFMergeSplitModelTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("mergesplit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makePDF(_ name: String, pages: Int) throws -> URL {
        let doc = PDFDocument()
        for i in 0..<pages {
            let image = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
                NSColor.red.setFill(); rect.fill(); return true
            }
            doc.insert(try XCTUnwrap(PDFPage(image: image)), at: i)
        }
        let url = dir.appendingPathComponent(name)
        XCTAssertTrue(doc.write(to: url))
        return url
    }

    func testMergeMoveAndRemove() throws {
        let a = try makePDF("a.pdf", pages: 1), b = try makePDF("b.pdf", pages: 2), c = try makePDF("c.pdf", pages: 3)
        let model = PDFMergeModel(urls: [a, b, c])
        XCTAssertEqual(model.items.map(\.pageCount), [1, 2, 3])
        XCTAssertEqual(model.items.map(\.name), ["a.pdf", "b.pdf", "c.pdf"])
        model.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(model.urls, [b, c, a])
        model.remove(at: 1)
        XCTAssertEqual(model.urls, [b, a])
        XCTAssertTrue(model.canSave)
        model.remove(at: 0)
        XCTAssertFalse(model.canSave)
        XCTAssertEqual(model.outputLabel, "merged")
    }

    func testSplitEveryPage() throws {
        let model = PDFSplitModel(url: try makePDF("s.pdf", pages: 4))
        XCTAssertEqual(model.pageCount, 4)
        XCTAssertEqual(model.ranges, [1...1, 2...2, 3...3, 4...4])
        XCTAssertEqual(model.summary, "Will create 4 files")
        XCTAssertTrue(model.canSave)
    }

    func testSplitRanges() throws {
        let model = PDFSplitModel(url: try makePDF("s.pdf", pages: 10))
        model.mode = .ranges
        XCTAssertFalse(model.canSave)
        XCTAssertNil(model.errorMessage)
        model.rangeText = "1-3, 4-10"
        XCTAssertEqual(model.ranges, [1...3, 4...10])
        XCTAssertEqual(model.summary, "Will create 2 files")
        XCTAssertTrue(model.canSave)
        model.rangeText = "5"
        XCTAssertEqual(model.summary, "Will create 1 file")
    }

    func testSplitInvalidRanges() throws {
        let model = PDFSplitModel(url: try makePDF("s.pdf", pages: 3))
        model.mode = .ranges
        model.rangeText = "2-9"
        XCTAssertNil(model.ranges)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.canSave)
        model.rangeText = "abc"
        XCTAssertNotNil(model.errorMessage)
    }

    func testSplitUnreadableFile() {
        let model = PDFSplitModel(url: dir.appendingPathComponent("missing.pdf"))
        XCTAssertEqual(model.pageCount, 0)
        XCTAssertFalse(model.canSave)
    }
}
