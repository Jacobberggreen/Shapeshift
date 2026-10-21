import XCTest
@testable import ConversionCore

final class FileFormatTests: XCTestCase {
    func testJpegUsesJpgExtension() {
        XCTAssertEqual(FileFormat.jpeg.fileExtension, "jpg")
    }

    func testParsesExtensionsCaseInsensitivelyWithAliases() {
        XCTAssertEqual(FileFormat(fileExtension: "JPG"), .jpeg)
        XCTAssertEqual(FileFormat(fileExtension: "jpeg"), .jpeg)
        XCTAssertEqual(FileFormat(fileExtension: "heif"), .heic)
        XCTAssertEqual(FileFormat(fileExtension: "tif"), .tiff)
        XCTAssertEqual(FileFormat(fileExtension: "aif"), .aiff)
        XCTAssertEqual(FileFormat(fileExtension: "MP4"), .mp4)
        XCTAssertNil(FileFormat(fileExtension: "xyz"))
    }

    func testParsesFromURL() {
        XCTAssertEqual(FileFormat(url: URL(fileURLWithPath: "/tmp/a.PNG")), .png)
    }

    func testFileExtensionsAreUnique() {
        let exts = FileFormat.allCases.map(\.fileExtension)
        XCTAssertEqual(Set(exts).count, exts.count)
    }

    func testImageTargetsExcludeSelfAndOtherKinds() {
        let t = FormatTable.candidateTargets(from: .png)
        XCTAssertFalse(t.contains(.png))
        XCTAssertTrue(t.contains(.jpeg))
        XCTAssertTrue(t.contains(.webp))
        XCTAssertTrue(t.allSatisfy { $0.kind == .image || $0 == .pdf })
    }

    func testAudioTargetsAreAudioOnly() {
        let t = FormatTable.candidateTargets(from: .wav)
        XCTAssertTrue(t.contains(.mp3))
        XCTAssertFalse(t.contains(.wav))
        XCTAssertTrue(t.allSatisfy { $0.kind == .audio })
    }

    func testVideoTargetsIncludeGifAndAudio() {
        let t = FormatTable.candidateTargets(from: .mp4)
        XCTAssertTrue(t.contains(.mkv))
        XCTAssertTrue(t.contains(.gif))
        XCTAssertTrue(t.contains(.mp3))
        XCTAssertFalse(t.contains(.mp4))
        XCTAssertFalse(t.contains(.png))
    }

    func testPDFAndTXTParseAndAreDocuments() {
        XCTAssertEqual(FileFormat(fileExtension: "PDF"), .pdf)
        XCTAssertEqual(FileFormat(fileExtension: "txt"), .txt)
        XCTAssertEqual(FileFormat.pdf.kind, .document)
        XCTAssertEqual(FileFormat.txt.kind, .document)
        XCTAssertEqual(FileFormat.pdf.displayName, "PDF")
        XCTAssertEqual(FileFormat.txt.displayName, "TXT")
    }

    func testPDFTargetsAreTXTOnly() {
        XCTAssertEqual(FormatTable.candidateTargets(from: .pdf), [.txt, .png, .jpeg])
    }


    func testImagesCanBecomePDF() {
        XCTAssertTrue(FormatTable.candidateTargets(from: .png).contains(.pdf))
        XCTAssertTrue(FormatTable.candidateTargets(from: .svg).contains(.pdf))
        XCTAssertFalse(FormatTable.candidateTargets(from: .svg).contains(.webp))
    }

    func testAudioAndVideoNeverOfferDocuments() {
        XCTAssertFalse(FormatTable.candidateTargets(from: .wav).contains(.pdf))
        XCTAssertFalse(FormatTable.candidateTargets(from: .mp4).contains(.txt))
    }

    func testEveryCandidateTargetIsSupportedBySomeDefaultConverter() {
        let service = ConversionService.makeDefault(ffmpeg: URL(fileURLWithPath: "/x/ffmpeg"))
        var unsupported: [String] = []
        for source in FileFormat.allCases {
            for target in FormatTable.candidateTargets(from: source) where service.targets(for:
                URL(fileURLWithPath: "/x/a.\(source.fileExtension)")).contains(target) == false {
                unsupported.append("\(source) -> \(target)")
            }
        }
        // Documented exception: HEIC cannot be written back out as WebP (ImageIO has no WebP encoder, ffmpeg has no HEIC decoder).
        XCTAssertEqual(unsupported, ["heic -> webp"], "unexpected unsupported pairs: \(unsupported)")
    }

    func testDocumentFormatsParseAndAreDocuments() {
        XCTAssertEqual(FileFormat(fileExtension: "DOCX"), .docx)
        XCTAssertEqual(FileFormat(fileExtension: "doc"), .doc)
        XCTAssertEqual(FileFormat(fileExtension: "odt"), .odt)
        XCTAssertEqual(FileFormat(fileExtension: "rtf"), .rtf)
        XCTAssertEqual(FileFormat(fileExtension: "html"), .html)
        XCTAssertEqual(FileFormat(fileExtension: "htm"), .html)
        XCTAssertEqual(FileFormat(fileExtension: "gdoc"), .gdoc)
        XCTAssertEqual(FileFormat(fileExtension: "txt"), .txt)
        for format in [FileFormat.docx, .doc, .odt, .rtf, .html, .gdoc] {
            XCTAssertEqual(format.kind, .document)
        }
        XCTAssertEqual(FileFormat.docx.displayName, "DOCX")
        XCTAssertEqual(FileFormat.html.displayName, "HTML")
        XCTAssertEqual(FileFormat.gdoc.displayName, "GDOC")
    }

    func testTextDocumentsCanBecomePDF() {
        for format in [FileFormat.docx, .doc, .odt, .rtf, .html, .txt] {
            XCTAssertEqual(FormatTable.candidateTargets(from: format), [.pdf], "\(format)")
        }
    }

    func testGDocHasNoTargets() {
        XCTAssertEqual(FormatTable.candidateTargets(from: .gdoc), [])
    }
}
