import XCTest
import PDFKit
import AppKit
@testable import ConversionCore

final class PDFConverterTests: XCTestCase {
    /// One-page PDF with `text` drawn in Helvetica 36 pt.
    private func makeTextPDF(at url: URL, text: String) throws {
        var box = CGRect(x: 0, y: 0, width: 400, height: 200)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw ConversionError.failed("fixture: cannot create PDF context")
        }
        ctx.beginPDFPage(nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 36)])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textPosition = CGPoint(x: 20, y: 80)
        CTLineDraw(line, ctx)
        ctx.endPDFPage()
        ctx.closePDF()
    }

    func testPNGToPDFWritesSinglePagePDF() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.png")
        makeTestPNG(at: input, width: 64, height: 32)
        let out = dir.file("out.pdf")
        try await PDFConverter().convert(input: input, from: .png, to: .pdf, output: out, options: ConversionOptions())
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
        let doc = try XCTUnwrap(PDFDocument(url: out))
        XCTAssertEqual(doc.pageCount, 1)
    }

    func testPDFToTXTExtractsText() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("in.pdf")
        try makeTextPDF(at: pdf, text: "Hello Shapeshift")
        let out = dir.file("out.txt")
        try await PDFConverter().convert(input: pdf, from: .pdf, to: .txt, output: out, options: ConversionOptions())
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertTrue(text.contains("Hello"), "extracted: \(text)")
    }

    func testImageOnlyPDFToTXTFails() async throws {
        let dir = TemporaryDirectory()
        let png = dir.file("in.png")
        makeTestPNG(at: png, width: 64, height: 32)
        let pdf = dir.file("scan.pdf")
        try await PDFConverter().convert(input: png, from: .png, to: .pdf, output: pdf, options: ConversionOptions())
        do {
            try await PDFConverter().convert(input: pdf, from: .pdf, to: .txt, output: dir.file("o.txt"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            guard case ConversionError.failed = error else { return XCTFail("unexpected error: \(error)") }
        }
    }

    func testUnsupportedPairThrows() async {
        let dir = TemporaryDirectory()
        let png = dir.file("in.png")
        makeTestPNG(at: png, width: 8, height: 8)
        do {
            try await PDFConverter().convert(input: png, from: .png, to: .txt, output: dir.file("o.txt"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unsupportedConversion(from: .png, to: .txt))
        }
    }

    func testServiceConvertsPNGToSiblingPDFAndOffersTXTForPDF() async throws {
        let dir = TemporaryDirectory()
        let png = dir.file("pic.png")
        makeTestPNG(at: png, width: 64, height: 32)
        let service = ConversionService.makeDefault(ffmpeg: nil)
        let out = try await service.convert(png, to: .pdf)
        XCTAssertEqual(out.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        XCTAssertEqual(out.pathExtension, "pdf")
        XCTAssertEqual(PDFDocument(url: out)?.pageCount, 1)
        XCTAssertEqual(service.targets(for: out), [.txt, .png, .jpeg])
    }

    // MARK: PDF -> PNG / JPG

    /// PDF with one page per entry in `pages` (in points), each with a filled rectangle so renders are not blank.
    private func makePagesPDF(at url: URL, pages: [CGSize], auxiliary: CFDictionary? = nil) throws {
        var box = CGRect(origin: .zero, size: pages.first ?? CGSize(width: 1, height: 1))
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, auxiliary) else {
            throw ConversionError.failed("fixture: cannot create PDF context")
        }
        for size in pages {
            let pageBox = CGRect(origin: .zero, size: size)
            ctx.beginPDFPage([kCGPDFContextMediaBox: pageBox.dictionaryRepresentation] as CFDictionary)
            ctx.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1))
            ctx.fill(CGRect(x: 10, y: 10, width: size.width / 2, height: size.height / 2))
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }

    private func imageInfo(_ url: URL) throws -> (type: String, width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "not an image: \(url.lastPathComponent)")
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let type = (CGImageSourceGetType(source) as String?) ?? ""
        return (type, props[kCGImagePropertyPixelWidth] as? Int ?? -1, props[kCGImagePropertyPixelHeight] as? Int ?? -1)
    }

    private func expectedPixels(_ points: CGFloat) -> Int { Int((points * 200 / 72).rounded()) }

    func testSinglePagePDFToPNGWritesOneImageAtTwoHundredDPI() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("page.pdf")
        try makePagesPDF(at: pdf, pages: [CGSize(width: 144, height: 72)])
        let out = dir.file("out.png")
        try await PDFConverter().convert(input: pdf, from: .pdf, to: .png, output: out, options: ConversionOptions())
        let info = try imageInfo(out)
        XCTAssertEqual(info.type, "public.png")
        XCTAssertTrue(abs(info.width - 400) <= 1, "info.width = \(info.width)")
        XCTAssertTrue(abs(info.height - 200) <= 1, "info.height = \(info.height)")
    }

    func testMultiPagePDFToJPGServiceMakesPagesFolder() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("report.pdf")
        try makePagesPDF(at: pdf, pages: Array(repeating: CGSize(width: 72, height: 72), count: 3))
        let service = ConversionService.makeDefault(ffmpeg: nil)

        let folder = try await service.convert(pdf, to: .jpeg)
        XCTAssertEqual(folder.lastPathComponent, "report pages")
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names, ["report 1.jpg", "report 2.jpg", "report 3.jpg"])
        for name in names {
            XCTAssertEqual(try imageInfo(folder.appendingPathComponent(name)).type, "public.jpeg", name)
        }

        let second = try await service.convert(pdf, to: .jpeg)
        XCTAssertEqual(second.lastPathComponent, "report pages 2")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 3)
    }

    func testTwelvePagePDFNamesAreZeroPadded() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("report.pdf")
        try makePagesPDF(at: pdf, pages: Array(repeating: CGSize(width: 72, height: 72), count: 12))
        let folder = try await ConversionService.makeDefault(ffmpeg: nil).convert(pdf, to: .png)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names.count, 12)
        XCTAssertEqual(names.first, "report 01.png")
        XCTAssertEqual(names.last, "report 12.png")
    }

    func testRotatedPageSwapsDimensions() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("tall.pdf")
        try makePagesPDF(at: pdf, pages: [CGSize(width: 100, height: 200)])
        let document = try XCTUnwrap(PDFDocument(url: pdf))
        document.page(at: 0)?.rotation = 90
        let rotated = dir.file("rotated.pdf")
        XCTAssertTrue(document.write(to: rotated))
        let out = dir.file("out.png")
        try await PDFConverter().convert(input: rotated, from: .pdf, to: .png, output: out, options: ConversionOptions())
        let info = try imageInfo(out)
        XCTAssertTrue(abs(info.width - expectedPixels(200)) <= 1, "info.width = \(info.width)")
        XCTAssertTrue(abs(info.height - expectedPixels(100)) <= 1, "info.height = \(info.height)")
    }

    func testVeryLargePageIsCappedAtSixThousandPixels() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("huge.pdf")
        try makePagesPDF(at: pdf, pages: [CGSize(width: 5000, height: 5000)])
        let out = dir.file("out.png")
        try await PDFConverter().convert(input: pdf, from: .pdf, to: .png, output: out, options: ConversionOptions())
        let info = try imageInfo(out)
        XCTAssertEqual(max(info.width, info.height), 6000)
        XCTAssertEqual(info.width, info.height)
    }

    func testGarbagePDFIsUnreadableAndLeavesNoStrayFiles() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("x.pdf")
        try Data("this is not a pdf".utf8).write(to: pdf)
        let service = ConversionService.makeDefault(ffmpeg: nil)
        do {
            _ = try await service.convert(pdf, to: .png)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unreadable(pdf))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.url.path), ["x.pdf"])
    }

    func testPasswordProtectedPDFFails() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("locked.pdf")
        let auxiliary = [kCGPDFContextOwnerPassword: "owner", kCGPDFContextUserPassword: "user"] as CFDictionary
        try makePagesPDF(at: pdf, pages: [CGSize(width: 72, height: 72)], auxiliary: auxiliary)
        do {
            try await PDFConverter().convert(input: pdf, from: .pdf, to: .png, output: dir.file("o.png"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .failed("The PDF is password protected."))
        }
    }

    /// The fixture's rectangle sits in the PDF's bottom-left quarter; the image must show it at the bottom-left, not flipped.
    func testRenderedPageIsNotFlipped() async throws {
        let dir = TemporaryDirectory()
        let pdf = dir.file("page.pdf")
        try makePagesPDF(at: pdf, pages: [CGSize(width: 144, height: 144)])
        let out = dir.file("out.png")
        try await PDFConverter().convert(input: pdf, from: .pdf, to: .png, output: out, options: ConversionOptions())
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(out as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                              bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        func rgb(x: Int, yFromTop: Int) -> (UInt8, UInt8, UInt8) {
            let o = (yFromTop * image.width + x) * 4
            return (pixels[o], pixels[o + 1], pixels[o + 2])
        }
        let bottomLeft = rgb(x: image.width / 4, yFromTop: image.height * 3 / 4)
        let topRight = rgb(x: image.width * 3 / 4, yFromTop: image.height / 4)
        XCTAssertGreaterThan(Int(bottomLeft.0) - Int(bottomLeft.2), 100, "bottom-left should be the red rectangle")
        XCTAssertGreaterThan(topRight.2, 240, "top-right should be white")
    }
}
