import XCTest
@testable import ConversionCore

final class OutputCommitterTests: XCTestCase {
    private func temp(in dir: TemporaryDirectory, content: String = "new") throws -> URL {
        let url = dir.file(".shapeshift-tmp.jpg")
        try Data(content.utf8).write(to: url)
        return url
    }

    func testLabelledSiblingName() {
        let dir = TemporaryDirectory()
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), fileExtension: "jpg", label: "cropped"),
                       dir.file("photo cropped.jpg"))
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), fileExtension: "jpg", label: nil),
                       dir.file("photo.jpg"))
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), fileExtension: "jpg", label: ""),
                       dir.file("photo.jpg"))
    }

    func testLabelledCollisionCounts() throws {
        let dir = TemporaryDirectory()
        try Data().write(to: dir.file("photo framed.png"))
        XCTAssertEqual(OutputPlanner.uniqueSibling(of: dir.file("photo.png"), fileExtension: "png", label: "framed"),
                       dir.file("photo framed 2.png"))
    }

    func testCommitMovesTempToSibling() throws {
        let dir = TemporaryDirectory()
        let t = try temp(in: dir)
        let out = try OutputCommitter.commit(temp: t, nextTo: dir.file("photo.png"), label: "framed", fileExtension: "jpg")
        XCTAssertEqual(out, dir.file("photo framed.jpg"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: t.path))
        XCTAssertEqual(try String(contentsOf: out), "new")
    }

    func testCommitNeverOverwritesExistingFile() throws {
        let dir = TemporaryDirectory()
        try Data("keep".utf8).write(to: dir.file("photo.jpg"))
        let out = try OutputCommitter.commit(temp: try temp(in: dir), nextTo: dir.file("photo.png"), fileExtension: "jpg")
        XCTAssertEqual(out, dir.file("photo 2.jpg"))
        XCTAssertEqual(try String(contentsOf: dir.file("photo.jpg")), "keep")
    }

    func testCommitRetriesWhenDestinationAppearsConcurrently() throws {
        // A FileManager that lets the first moveItem collide, simulating a concurrent job taking the name.
        final class RacingFileManager: FileManager {
            var raced = false
            override func moveItem(at src: URL, to dst: URL) throws {
                if !raced {
                    raced = true
                    try Data("other".utf8).write(to: dst)
                }
                try super.moveItem(at: src, to: dst)
            }
        }
        let dir = TemporaryDirectory()
        let fm = RacingFileManager()
        let out = try OutputCommitter.commit(temp: try temp(in: dir), nextTo: dir.file("photo.png"),
                                             fileExtension: "jpg", fileManager: fm)
        XCTAssertEqual(out, dir.file("photo 2.jpg"))
        XCTAssertEqual(try String(contentsOf: dir.file("photo.jpg")), "other")
    }

    func testCommitFailsAfterBoundedAttemptsAndLeavesTempForTheCaller() throws {
        let dir = TemporaryDirectory()
        let t = try temp(in: dir)
        let missingDir = dir.file("no-such-dir/photo.png")        // moveItem fails with a non-"exists" error
        XCTAssertThrowsError(try OutputCommitter.commit(temp: t, nextTo: missingDir, fileExtension: "jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: t.path))
    }

    func testCommitFolderMovesDirectoryAsPagesFolder() throws {
        let dir = TemporaryDirectory()
        let pages = dir.file(".shapeshift-pages.png")
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        try Data("one".utf8).write(to: pages.appendingPathComponent("report 1.png"))
        try Data("two".utf8).write(to: pages.appendingPathComponent("report 2.png"))

        let out = try OutputCommitter.commitFolder(temp: pages, nextTo: dir.file("report.pdf"))
        XCTAssertEqual(out.lastPathComponent, "report pages")
        XCTAssertEqual(out.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pages.path))
        XCTAssertEqual(try String(contentsOf: out.appendingPathComponent("report 2.png")), "two")
    }

    func testCommitFolderNeverOverwritesExistingFolder() throws {
        let dir = TemporaryDirectory()
        try FileManager.default.createDirectory(at: dir.file("report pages"), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: dir.file("report pages/a.png"))
        let pages = dir.file(".shapeshift-pages.png")
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: pages.appendingPathComponent("b.png"))

        let out = try OutputCommitter.commitFolder(temp: pages, nextTo: dir.file("report.pdf"))
        XCTAssertEqual(out.lastPathComponent, "report pages 2")
        XCTAssertEqual(out.deletingLastPathComponent().standardizedFileURL, dir.url.standardizedFileURL)
        XCTAssertEqual(try String(contentsOf: dir.file("report pages/a.png")), "keep")
        XCTAssertEqual(try String(contentsOf: out.appendingPathComponent("b.png")), "new")
    }
}
