import XCTest
import AppKit
@testable import ShapeshiftApp

final class ServiceFilesTests: XCTestCase {
    private var dir: URL!
    private var pasteboard: NSPasteboard!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("svc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        pasteboard = NSPasteboard(name: NSPasteboard.Name("shapeshift-test-\(UUID().uuidString)"))
    }

    override func tearDownWithError() throws {
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: dir)
    }

    private func file(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data([1, 2, 3]).write(to: url)
        return url
    }

    private func put(_ urls: [URL]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    func testKeepsExistingFilesInOrder() throws {
        let a = try file("a.png"), b = try file("b.png")
        put([b, a])
        XCTAssertEqual(ServiceFiles.urls(from: pasteboard).map(\.lastPathComponent), ["b.png", "a.png"])
    }

    func testDropsMissingFilesAndDirectories() throws {
        let a = try file("a.png")
        let folder = dir.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let missing = dir.appendingPathComponent("gone.png")
        put([a, folder, missing])
        XCTAssertEqual(ServiceFiles.urls(from: pasteboard).map(\.lastPathComponent), ["a.png"])
    }

    func testEmptyPasteboardGivesNoFiles() {
        pasteboard.clearContents()
        XCTAssertEqual(ServiceFiles.urls(from: pasteboard), [])
    }

    func testDuplicatesAreRemoved() throws {
        let a = try file("a.png")
        put([a, a])
        XCTAssertEqual(ServiceFiles.urls(from: pasteboard).count, 1)
    }

    @MainActor
    func testProviderCallsBackWithFiles() throws {
        let a = try file("a.png")
        put([a])
        let provider = ServiceProvider()
        var received: [URL] = []
        provider.onFiles = { received = $0 }
        var error: NSString = ""
        provider.openWithShapeshift(pasteboard, userData: "", error: &error)
        XCTAssertEqual(received.map(\.lastPathComponent), ["a.png"])
        XCTAssertEqual(error, "")
    }

    @MainActor
    func testProviderReportsErrorWhenNothingUsable() {
        pasteboard.clearContents()
        let provider = ServiceProvider()
        var called = false
        provider.onFiles = { _ in called = true }
        var error: NSString = ""
        provider.openWithShapeshift(pasteboard, userData: "", error: &error)
        XCTAssertFalse(called)
        XCTAssertNotEqual(error, "")
    }
}
