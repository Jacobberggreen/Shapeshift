import XCTest
@testable import ConversionCore

private struct FakeConverter: Converter {
    var failAfterWriting = false

    func supports(from: FileFormat, to: FileFormat) -> Bool {
        from != to && from.kind == .image && to.kind == .image
    }

    func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        try Data("partial".utf8).write(to: output)
        if failAfterWriting { throw ConversionError.failed("boom") }
    }
}

/// Writes partial output, then waits (cancellable) as a long-running conversion would.
private struct SlowConverter: Converter {
    func supports(from: FileFormat, to: FileFormat) -> Bool {
        from != to && from.kind == .image && to.kind == .image
    }

    func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        try Data("partial".utf8).write(to: output)
        try await Task.sleep(nanoseconds: 5_000_000_000)
    }
}

/// Simulates a concurrent job claiming the expected final name while converting.
private struct RacingConverter: Converter {
    let racedFile: URL

    func supports(from: FileFormat, to: FileFormat) -> Bool {
        from != to && from.kind == .image && to.kind == .image
    }

    func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        try Data("partial".utf8).write(to: output)
        try Data("other job".utf8).write(to: racedFile)
    }
}

final class ConversionServiceTests: XCTestCase {
    private func makeInput(_ dir: TemporaryDirectory, _ name: String, content: String = "original") throws -> URL {
        let url = dir.file(name)
        try Data(content.utf8).write(to: url)
        return url
    }

    func testConvertWritesSiblingAndLeavesOriginalUntouched() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        let out = try await ConversionService(converters: [FakeConverter()]).convert(input, to: .jpeg)
        XCTAssertEqual(out, dir.file("a.jpg"))
        XCTAssertEqual(try String(contentsOf: input), "original")
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }

    func testExistingOutputIsNeverOverwritten() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        _ = try makeInput(dir, "a.jpg", content: "keep me")
        let out = try await ConversionService(converters: [FakeConverter()]).convert(input, to: .jpeg)
        XCTAssertEqual(out, dir.file("a 2.jpg"))
        XCTAssertEqual(try String(contentsOf: dir.file("a.jpg")), "keep me")
    }

    func testFailureRemovesTempFileAndLeavesNoOutput() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        let service = ConversionService(converters: [FakeConverter(failAfterWriting: true)])
        do {
            _ = try await service.convert(input, to: .jpeg)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .failed("boom"))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
        XCTAssertEqual(names, ["a.png"])
    }

    func testUnknownExtensionThrowsUnsupportedFile() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.xyz")
        do {
            _ = try await ConversionService(converters: [FakeConverter()]).convert(input, to: .jpeg)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unsupportedFile(input))
        }
    }

    func testNoCapableConverterThrowsUnsupportedConversion() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        do {
            _ = try await ConversionService(converters: [FakeConverter()]).convert(input, to: .mp3)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .unsupportedConversion(from: .png, to: .mp3))
        }
    }

    func testBatchContinuesAfterFailure() async throws {
        let dir = TemporaryDirectory()
        let good1 = try makeInput(dir, "a.png")
        let bad = try makeInput(dir, "b.xyz")
        let good2 = try makeInput(dir, "c.png")
        let results = await ConversionService(converters: [FakeConverter()]).convert([good1, bad, good2], to: .jpeg)
        XCTAssertEqual(results.count, 3)
        XCTAssertNoThrow(try results[0].result.get())
        XCTAssertThrowsError(try results[1].result.get())
        XCTAssertNoThrow(try results[2].result.get())
    }

    func testTargetsOnlyListWhatSomeConverterCanDo() {
        let service = ConversionService(converters: [FakeConverter()])
        let targets = service.targets(for: URL(fileURLWithPath: "/x/a.png"))
        XCTAssertTrue(targets.contains(.jpeg))
        XCTAssertFalse(targets.contains(.png))
        XCTAssertTrue(service.targets(for: URL(fileURLWithPath: "/x/a.mp3")).isEmpty)
        XCTAssertTrue(service.targets(for: URL(fileURLWithPath: "/x/a.xyz")).isEmpty)
    }

    func testCommonTargetsIntersect() {
        let service = ConversionService(converters: [FakeConverter()])
        let common = service.commonTargets(for: [URL(fileURLWithPath: "/x/a.png"), URL(fileURLWithPath: "/x/b.jpg")])
        XCTAssertFalse(common.contains(.png))
        XCTAssertFalse(common.contains(.jpeg))
        XCTAssertTrue(common.contains(.tiff))
        XCTAssertTrue(service.commonTargets(for: []).isEmpty)
    }

    func testRealPNGToJPEGEndToEnd() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("pic.png")
        makeTestPNG(at: input)
        let out = try await ConversionService.makeDefault().convert(input, to: .jpeg)
        XCTAssertEqual(out.lastPathComponent, "pic.jpg")
        XCTAssertGreaterThan(try Data(contentsOf: out).count, 0)
    }

    // MARK: cancellation

    func testCancelledSingleConversionFinishesQuicklyAndLeavesNoTempFile() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        let service = ConversionService(converters: [SlowConverter()])
        let task = Task { try await service.convert(input, to: .jpeg) }
        try await Task.sleep(nanoseconds: 300_000_000)
        let start = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? ConversionError) == .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.url.path), ["a.png"])
    }

    func testCancelledBatchMarksRemainingInputsCancelledAndLeavesNoTempFiles() async throws {
        let dir = TemporaryDirectory()
        let inputs = try ["a.png", "b.png", "c.png"].map { try makeInput(dir, $0) }
        let service = ConversionService(converters: [SlowConverter()])
        let task = Task { await service.convert(inputs, to: .jpeg) }
        try await Task.sleep(nanoseconds: 300_000_000)
        let start = Date()
        task.cancel()
        let results = await task.value
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertEqual(results.map(\.input), inputs)
        for r in results {
            guard case .failure(let error) = r.result else { return XCTFail("expected failure") }
            XCTAssertEqual(error, .cancelled)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path).sorted()
        XCTAssertEqual(names, ["a.png", "b.png", "c.png"])
    }

    // MARK: concurrent name race

    func testRaceForOutputNameRetriesWithNextFreeName() async throws {
        let dir = TemporaryDirectory()
        let input = try makeInput(dir, "a.png")
        let service = ConversionService(converters: [RacingConverter(racedFile: dir.file("a.jpg"))])
        let out = try await service.convert(input, to: .jpeg)
        XCTAssertEqual(out, dir.file("a 2.jpg"))
        XCTAssertEqual(try String(contentsOf: dir.file("a.jpg")), "other job")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path).sorted()
        XCTAssertEqual(names, ["a 2.jpg", "a.jpg", "a.png"])
    }
}
