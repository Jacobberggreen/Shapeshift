import XCTest
@testable import EditCore

final class FrameStyleCodingTests: XCTestCase {
    private func decode(_ json: String) throws -> FrameStyle {
        try JSONDecoder().decode(FrameStyle.self, from: Data(json.utf8))
    }

    func testEmptyObjectDecodesToDefaults() throws {
        XCTAssertEqual(try decode("{}"), FrameStyle())
    }

    func testPartialObjectKeepsDefaultsElsewhere() throws {
        let style = try decode(#"{"cornerRadius": 12, "windowChrome": true}"#)
        var expected = FrameStyle()
        expected.cornerRadius = 12
        expected.windowChrome = true
        XCTAssertEqual(style, expected)
    }

    func testFullRoundTrip() throws {
        var style = FrameStyle()
        style.cornerRadius = 9; style.borderWidth = 2; style.windowChrome = true
        style.theme = .dark; style.title = "T"; style.inactive = true
        style.shadowEnabled = true; style.shadowOffsetX = 1; style.shadowOffsetY = 2
        style.shadowBlur = 3; style.shadowOpacity = 0.6; style.margin = 7
        style.backgroundColor = RGBAColor(r: 1, g: 0, b: 0, a: 1)
        let data = try JSONEncoder().encode(style)
        XCTAssertEqual(try JSONDecoder().decode(FrameStyle.self, from: data), style)
    }
}
