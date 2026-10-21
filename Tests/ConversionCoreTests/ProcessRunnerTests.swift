import XCTest
@testable import ConversionCore

final class ProcessRunnerTests: XCTestCase {
    func testSuccessfulProcessReturns() async throws {
        try await ProcessRunner.run(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
    }

    func testNonZeroExitThrowsFailed() async {
        do {
            try await ProcessRunner.run(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [])
            XCTFail("expected throw")
        } catch ConversionError.failed(let message) {
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testStderrIsReportedInError() async {
        do {
            try await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "echo boom >&2; exit 3"])
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .failed("boom"))
        }
    }

    func testCancellationTerminatesProcess() async throws {
        let started = Date()
        let task = Task {
            try await ProcessRunner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"])
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        do {
            try await task.value
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ConversionError, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testMissingExecutableThrowsFailed() async {
        do {
            try await ProcessRunner.run(executable: URL(fileURLWithPath: "/nonexistent/tool"), arguments: [])
            XCTFail("expected throw")
        } catch {
            guard case ConversionError.failed = error else { return XCTFail("got \(error)") }
        }
    }

    func testLargeStderrDoesNotHang() async {
        do {
            try await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "head -c 300000 /dev/zero | tr '\\0' 'x' >&2; exit 3"])
            XCTFail("expected throw")
        } catch ConversionError.failed(let message) {
            XCTAssertFalse(message.isEmpty)
            XCTAssertLessThanOrEqual(message.count, 8192)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}
