import XCTest
import PDFKit
import AppKit
@testable import ConversionCore

final class DocumentConverterTests: XCTestCase {
    /// Writes `text` into a document of the given AppKit type, as the input file would be produced by any word processor.
    private func makeDocument(at url: URL, text: String, type: NSAttributedString.DocumentType) throws {
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)])
        let data = try attributed.data(from: NSRange(location: 0, length: attributed.length),
                                       documentAttributes: [.documentType: type])
        try data.write(to: url)
    }

    private func convertToPDF(_ input: URL, from: FileFormat) async throws -> PDFDocument {
        let out = input.deletingPathExtension().appendingPathExtension("pdf")
        try await DocumentConverter().convert(input: input, from: from, to: .pdf, output: out, options: ConversionOptions())
        return try XCTUnwrap(PDFDocument(url: out), "output is not a readable PDF")
    }

    func testRTFToPDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.rtf")
        try makeDocument(at: input, text: "Zanzibarrtf sample", type: .rtf)
        let pdf = try await convertToPDF(input, from: .rtf)
        XCTAssertGreaterThanOrEqual(pdf.pageCount, 1)
        XCTAssertTrue(pdf.string?.contains("Zanzibarrtf") ?? false)
    }

    func testHTMLToPDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.html")
        try Data("<html><body><p>Zanzibarhtml sample</p></body></html>".utf8).write(to: input)
        let pdf = try await convertToPDF(input, from: .html)
        XCTAssertTrue(pdf.string?.contains("Zanzibarhtml") ?? false)
    }

    func testTXTToPDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.txt")
        try Data("Zanzibartxt sample".utf8).write(to: input)
        let pdf = try await convertToPDF(input, from: .txt)
        XCTAssertTrue(pdf.string?.contains("Zanzibartxt") ?? false)
    }

    func testDOCXToPDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.docx")
        try makeDocument(at: input, text: "Zanzibardocx sample", type: .officeOpenXML)
        let pdf = try await convertToPDF(input, from: .docx)
        XCTAssertTrue(pdf.string?.contains("Zanzibardocx") ?? false)
    }

    func testODTToPDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.odt")
        try makeDocument(at: input, text: "Zanzibarodt sample", type: .openDocument)
        let pdf = try await convertToPDF(input, from: .odt)
        XCTAssertTrue(pdf.string?.contains("Zanzibarodt") ?? false)
    }

    func testLongTextSpansMultiplePages() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("long.txt")
        let text = (1...200).map { "Line \($0) of a long document." }.joined(separator: "\n")
        try Data(text.utf8).write(to: input)
        let pdf = try await convertToPDF(input, from: .txt)
        XCTAssertGreaterThan(pdf.pageCount, 1)
    }

    func testGarbageDOCXIsUnreadable() async {
        let dir = TemporaryDirectory()
        let input = dir.file("bad.docx")
        try? Data((0..<512).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) }).write(to: input)
        do {
            try await DocumentConverter().convert(input: input, from: .docx, to: .pdf,
                                                  output: dir.file("bad.pdf"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unreadable(input))
        }
    }

    func testServiceOffersPDFForRTFAndConvertsSibling() async throws {
        let dir = TemporaryDirectory()
        let rtf = dir.file("note.rtf")
        try makeDocument(at: rtf, text: "Zanzibarservice sample", type: .rtf)
        let service = ConversionService.makeDefault(ffmpeg: nil)
        XCTAssertEqual(service.targets(for: rtf), [.pdf])
        let out = try await service.convert(rtf, to: .pdf)
        XCTAssertEqual(out.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        XCTAssertEqual(out.pathExtension, "pdf")
        XCTAssertEqual(PDFDocument(url: out)?.string?.contains("Zanzibarservice"), true)
    }

    func testGDocFailsWithFriendlyMessage() async throws {
        let dir = TemporaryDirectory()
        let gdoc = dir.file("Report.gdoc")
        try Data("{\"doc_id\": \"abc\"}".utf8).write(to: gdoc)
        let service = ConversionService.makeDefault(ffmpeg: nil)
        XCTAssertEqual(service.targets(for: gdoc), [])
        do {
            _ = try await service.convert(gdoc, to: .pdf)
            XCTFail("expected throw")
        } catch let error as ConversionError {
            guard case .failed(let message) = error else { return XCTFail("unexpected error: \(error)") }
            XCTAssertTrue(message.contains("Google Doc"), message)
            XCTAssertTrue(error.localizedDescription.contains("Google Doc"))
        }
    }
}
