import XCTest
import PDFKit
import AppKit
@testable import ConversionCore

final class PDFOperationsTests: XCTestCase {
    /// PDF with one page per entry in `pages`, each showing its text in Helvetica 36 pt at 20, 80.
    private func makeTextPDF(at url: URL, pages: [String], size: CGSize = CGSize(width: 400, height: 200)) throws {
        var box = CGRect(origin: .zero, size: size)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw ConversionError.failed("fixture: cannot create PDF context")
        }
        for text in pages {
            ctx.beginPDFPage(nil)
            let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 36)])
            ctx.textPosition = CGPoint(x: 20, y: 80)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }

    private func document(_ pages: [String], in dir: TemporaryDirectory, name: String = "src.pdf") throws -> PDFDocument {
        let url = dir.file(name)
        try makeTextPDF(at: url, pages: pages)
        return try XCTUnwrap(PDFDocument(url: url))
    }

    private func text(_ document: PDFDocument, _ index: Int) -> String {
        document.page(at: index)?.string ?? ""
    }

    private func assertFailed<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case ConversionError.failed = error else {
                return XCTFail("expected ConversionError.failed, got \(error)", file: file, line: line)
            }
        }
    }

    // MARK: PageRanges

    func testParseValidRangesKeepsTypedOrder() throws {
        XCTAssertEqual(try PageRanges.parse("1-3, 5, 7-9", pageCount: 10), [1...3, 5...5, 7...9])
        XCTAssertEqual(try PageRanges.parse("5, 1-2", pageCount: 5), [5...5, 1...2])
    }

    func testParseToleratesSpacesSemicolonsAndDashVariants() throws {
        XCTAssertEqual(try PageRanges.parse("  2 ; 4  ", pageCount: 5), [2...2, 4...4])
        XCTAssertEqual(try PageRanges.parse("1\u{2013}2, 3\u{2014}4", pageCount: 4), [1...2, 3...4])
        XCTAssertEqual(try PageRanges.parse("1 - 2,", pageCount: 4), [1...2])
    }

    func testParseRejectsEmptyReversedOutOfRangeAndGarbage() {
        assertFailed(try PageRanges.parse("", pageCount: 5))
        assertFailed(try PageRanges.parse("  ,  ", pageCount: 5))
        assertFailed(try PageRanges.parse("3-1", pageCount: 5))
        assertFailed(try PageRanges.parse("0", pageCount: 5))
        assertFailed(try PageRanges.parse("6", pageCount: 5))
        assertFailed(try PageRanges.parse("1-9", pageCount: 5))
        assertFailed(try PageRanges.parse("abc", pageCount: 5))
        assertFailed(try PageRanges.parse("1..3", pageCount: 5))
        assertFailed(try PageRanges.parse("1-", pageCount: 5))
        assertFailed(try PageRanges.parse("1.5", pageCount: 5))
    }

    // MARK: rebuild

    func testRebuildReordersDeletesAndRotates() throws {
        let dir = TemporaryDirectory()
        let source = try document(["Page ONE secret", "Page TWO", "Page THREE"], in: dir)
        let result = try PDFOperations.rebuild(source, edits: [
            PDFPageEdit(sourceIndex: 2),
            PDFPageEdit(sourceIndex: 0, rotation: 90),
        ])
        XCTAssertEqual(result.pageCount, 2)
        XCTAssertTrue(text(result, 0).contains("THREE"), text(result, 0))
        XCTAssertTrue(text(result, 1).contains("ONE"), text(result, 1))
        XCTAssertEqual(result.page(at: 0)?.rotation, 0)
        XCTAssertEqual(result.page(at: 1)?.rotation, 90)
    }

    func testRebuildNormalisesRotationAndLeavesSourceUntouched() throws {
        let dir = TemporaryDirectory()
        let source = try document(["Only"], in: dir)
        source.page(at: 0)?.rotation = 270
        let result = try PDFOperations.rebuild(source, edits: [PDFPageEdit(sourceIndex: 0, rotation: 180)])
        XCTAssertEqual(result.page(at: 0)?.rotation, 90)
        XCTAssertEqual(source.pageCount, 1)
        XCTAssertEqual(source.page(at: 0)?.rotation, 270)
    }

    func testRebuildRejectsEmptyEditsAndOutOfRangeIndex() throws {
        let dir = TemporaryDirectory()
        let source = try document(["A", "B"], in: dir)
        assertFailed(try PDFOperations.rebuild(source, edits: []))
        assertFailed(try PDFOperations.rebuild(source, edits: [PDFPageEdit(sourceIndex: 2)]))
        assertFailed(try PDFOperations.rebuild(source, edits: [PDFPageEdit(sourceIndex: -1)]))
    }

    // MARK: merge

    func testMergeTwoPDFsAndAnImageKeepsOrder() throws {
        let dir = TemporaryDirectory()
        let first = dir.file("first.pdf")
        try makeTextPDF(at: first, pages: ["First"])
        let second = dir.file("second.pdf")
        try makeTextPDF(at: second, pages: ["Second A", "Second B"])
        let png = dir.file("pic.png")
        makeTestPNG(at: png, width: 64, height: 32)

        let merged = try PDFOperations.merge([first, png, second])
        XCTAssertEqual(merged.pageCount, 4)
        XCTAssertTrue(text(merged, 0).contains("First"), text(merged, 0))
        XCTAssertEqual(text(merged, 1), "")
        XCTAssertTrue(text(merged, 2).contains("Second A"), text(merged, 2))
        XCTAssertTrue(text(merged, 3).contains("Second B"), text(merged, 3))
    }

    func testMergeUnreadableInputThrowsNamingTheFile() throws {
        let dir = TemporaryDirectory()
        let bad = dir.file("broken.pdf")
        try Data("not a pdf".utf8).write(to: bad)
        XCTAssertThrowsError(try PDFOperations.merge([bad])) { error in
            XCTAssertEqual(error as? ConversionError, .unreadable(bad))
        }
    }

    // MARK: split

    func testSplitByRangesMakesOneDocumentPerRange() throws {
        let dir = TemporaryDirectory()
        let source = try document(["P1", "P2", "P3", "P4"], in: dir)
        let parts = try PDFOperations.split(source, ranges: [1...2, 4...4])
        XCTAssertEqual(parts.map(\.pageCount), [2, 1])
        XCTAssertTrue(text(parts[0], 1).contains("P2"), text(parts[0], 1))
        XCTAssertTrue(text(parts[1], 0).contains("P4"), text(parts[1], 0))
        XCTAssertEqual(source.pageCount, 4)
        assertFailed(try PDFOperations.split(source, ranges: [4...5]))
        assertFailed(try PDFOperations.split(source, ranges: []))
    }

    func testEveryPageGivesOneRangePerPage() throws {
        let dir = TemporaryDirectory()
        let source = try document(["A", "B", "C"], in: dir)
        XCTAssertEqual(PDFOperations.everyPage(source), [1...1, 2...2, 3...3])
    }

    // MARK: redact

    func testRedactRemovesTextOnlyFromBoxedPage() throws {
        let dir = TemporaryDirectory()
        let source = try document(["Page ONE secret", "Page TWO open"], in: dir)
        let originalSize = try XCTUnwrap(source.page(at: 0)).bounds(for: .mediaBox).size
        let redacted = try PDFOperations.redact(source, boxes: [0: [CGRect(x: 0, y: 0, width: 1, height: 1)]])

        XCTAssertEqual(redacted.pageCount, 2)
        XCTAssertFalse(text(redacted, 0).contains("secret"), text(redacted, 0))
        XCTAssertTrue(text(redacted, 1).contains("TWO"), text(redacted, 1))
        XCTAssertEqual(redacted.page(at: 0)?.bounds(for: .mediaBox).size, originalSize)
        XCTAssertTrue(text(source, 0).contains("secret"), "source must be untouched")
    }

    func testRedactClampsBoxesToThePage() throws {
        let dir = TemporaryDirectory()
        let source = try document(["Page ONE secret"], in: dir)
        let redacted = try PDFOperations.redact(source, boxes: [0: [CGRect(x: -1, y: -1, width: 3, height: 3)]])
        XCTAssertFalse(text(redacted, 0).contains("secret"), text(redacted, 0))
        XCTAssertEqual(redacted.page(at: 0)?.bounds(for: .mediaBox).size, CGSize(width: 400, height: 200))
    }

    // MARK: save

    func testSaveNamesOutputUniquelyNextToInput() throws {
        let dir = TemporaryDirectory()
        let source = try document(["Hello"], in: dir, name: "a.pdf")
        let first = try PDFOperations.save(source, nextTo: dir.file("a.pdf"), label: "edited")
        XCTAssertEqual(first.lastPathComponent, "a edited.pdf")
        let second = try PDFOperations.save(source, nextTo: dir.file("a.pdf"), label: "edited")
        XCTAssertEqual(second.lastPathComponent, "a edited 2.pdf")
        XCTAssertEqual(PDFDocument(url: second)?.pageCount, 1)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path).sorted()
        XCTAssertEqual(names, ["a edited 2.pdf", "a edited.pdf", "a.pdf"])
    }

    func testSavePartsFolderNamesFilesAndPadsTwelveParts() throws {
        let dir = TemporaryDirectory()
        let source = try document((1...12).map { "Part \($0)" }, in: dir, name: "a.pdf")
        let parts = try PDFOperations.split(source, ranges: PDFOperations.everyPage(source))
        let folder = try PDFOperations.savePartsFolder(parts, nextTo: dir.file("a.pdf"))
        XCTAssertEqual(folder.lastPathComponent, "a parts")
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names.count, 12)
        XCTAssertEqual(names.first, "a 01.pdf")
        XCTAssertEqual(names.last, "a 12.pdf")

        let second = try PDFOperations.savePartsFolder(parts, nextTo: dir.file("a.pdf"))
        XCTAssertEqual(second.lastPathComponent, "a parts 2")
    }
}
