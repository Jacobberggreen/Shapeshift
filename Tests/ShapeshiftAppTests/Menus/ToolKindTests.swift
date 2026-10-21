import XCTest
@testable import ShapeshiftApp

final class ToolKindTests: XCTestCase {
    private func urls(_ names: String...) -> [URL] { names.map { URL(fileURLWithPath: "/tmp/\($0)") } }

    func testImagesGetImageTools() {
        XCTAssertEqual(ToolKind.available(for: urls("a.png", "b.jpg")), EditTool.allCases.map(ToolKind.image))
    }

    func testSinglePDF() {
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf")), [.pdf(.pages), .pdf(.split), .pdf(.redact)])
    }

    func testSeveralPDFsAddMerge() {
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf", "b.pdf")),
                       [.pdf(.pages), .pdf(.split), .pdf(.merge), .pdf(.redact)])
    }

    func testPDFsAndImagesOnlyMerge() {
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf", "b.png")), [.pdf(.merge)])
        XCTAssertEqual(ToolKind.available(for: urls("a.svg", "b.pdf", "c.jpg")), [.pdf(.merge)])
    }

    func testEverythingElseHasNoTools() {
        XCTAssertEqual(ToolKind.available(for: []), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.mp3")), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.docx")), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf")).isEmpty, false)
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf", "b.mp4")), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf", "b.txt")), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.pdf", "b.unknown")), [])
        XCTAssertEqual(ToolKind.available(for: urls("a.png", "b.mp3")), [])
    }

    func testIdsAreUniqueAndTitlesForward() {
        let all = EditTool.allCases.map(ToolKind.image) + PDFTool.allCases.map(ToolKind.pdf)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(PDFTool.allCases.map(\.title), ["Pages", "Split", "Merge", "Redact"])
        XCTAssertEqual(ToolKind.pdf(.split).symbolName, "scissors")
        XCTAssertEqual(ToolKind.image(.crop).title, "Crop")
    }
}
