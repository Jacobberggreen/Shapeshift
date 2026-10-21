import XCTest
import Combine
import ConversionCore
@testable import ShapeshiftApp

@MainActor
final class WheelModelTests: XCTestCase {
    private let formats = Array(FileFormat.allCases.prefix(4))
    private let tools = EditTool.allCases.map(ToolKind.image)

    private func model(_ style: MenuStyle, formats: [FileFormat]? = nil, tools: [ToolKind]? = nil,
                       count: Int = 3) -> WheelModel {
        WheelModel(style: style, formats: formats ?? self.formats, tools: tools ?? self.tools, fileCount: count)
    }

    func testTwoRingsShowsEverythingAtOnce() {
        let m = model(.twoRings)
        XCTAssertEqual(m.step, .root)
        XCTAssertEqual(m.items.count, formats.count + tools.count)
    }

    func testTwoStepsStartsAtTheRootWhenBothKindsExist() {
        let m = model(.twoSteps)
        XCTAssertEqual(m.step, .root)
        XCTAssertEqual(m.items.map(\.entry), [.category(.convert), .category(.tools)])
    }

    func testTwoStepsSkipsTheRootWithOnlyOneKind() {
        XCTAssertEqual(model(.twoSteps, tools: []).step, .category(.convert))
        XCTAssertEqual(model(.twoSteps, formats: []).step, .category(.tools))
        XCTAssertEqual(model(.twoSteps, tools: []).items.count, formats.count)
    }

    func testEnterAndBackClearTheSelection() {
        let m = model(.twoSteps)
        m.selected = 1
        m.enter(.tools)
        XCTAssertEqual(m.step, .category(.tools))
        XCTAssertNil(m.selected)
        m.selected = 0
        XCTAssertTrue(m.back())
        XCTAssertEqual(m.step, .root)
        XCTAssertNil(m.selected)
        XCTAssertFalse(m.back())
    }

    func testEscapeGoesBackThenCloses() {
        let m = model(.twoSteps)
        m.enter(.convert)
        XCTAssertEqual(m.handle(keyCode: 53), .handled)
        XCTAssertEqual(m.step, .root)
        XCTAssertEqual(m.handle(keyCode: 53), .close)
        XCTAssertEqual(model(.twoRings).handle(keyCode: 53), .close)
        XCTAssertEqual(model(.twoSteps, tools: []).handle(keyCode: 53), .close)   // no root to go back to
    }

    func testReturnOnACategoryEntersItInsteadOfChoosing() {
        let m = model(.twoSteps)
        XCTAssertEqual(m.handle(keyCode: 124), .handled)       // first arrow selects the topmost item
        XCTAssertEqual(m.selected, 0)
        XCTAssertEqual(m.handle(keyCode: 36), .handled)
        XCTAssertEqual(m.step, .category(.convert))
    }

    func testReturnOnAnActionChooses() {
        let m = model(.twoRings)
        m.selected = 0
        XCTAssertEqual(m.handle(keyCode: 36), .choose(.format(formats[0])))
        XCTAssertEqual(m.handle(keyCode: 76), .choose(.format(formats[0])))
        m.selected = formats.count
        XCTAssertEqual(m.handle(keyCode: 36), .choose(.tool(tools[0])))
    }

    func testReturnWithoutSelectionAndUnknownKeys() {
        let m = model(.twoRings)
        XCTAssertEqual(m.handle(keyCode: 36), .handled)
        XCTAssertEqual(m.handle(keyCode: 0), .ignored)
    }

    func testHubTextFollowsTheSelection() {
        let m = model(.twoRings, count: 3)
        XCTAssertEqual(m.hubTitle, "Shapeshift")
        XCTAssertEqual(m.hubDetail, "3 files")
        m.selected = 0
        XCTAssertEqual(m.hubTitle, formats[0].displayName)
        m.selected = formats.count
        XCTAssertEqual(m.hubTitle, tools[0].title)
        XCTAssertEqual(model(.twoRings, count: 1).hubDetail, "1 file")
        let steps = model(.twoSteps)
        steps.enter(.tools)
        XCTAssertEqual(steps.hubTitle, "Tools")
    }

    private func model(bytes: Int?, estimate: (@Sendable (FileFormat) async -> Int?)?, count: Int = 1,
                       style: MenuStyle = .twoRings) -> WheelModel {
        WheelModel(style: style, formats: formats, tools: tools, fileCount: count,
                   outcome: WheelOutcomeSource(sourceFormat: .png, sourceBytes: bytes, estimate: estimate))
    }

    func testDefaultHubShowsSourceFormatAndSize() {
        let m = model(bytes: 1_100_000, estimate: nil)
        XCTAssertEqual(m.hubTitle, "PNG")
        XCTAssertEqual(m.hubDetail, WheelModel.sizeText(1_100_000))
    }

    func testMultipleFilesAddTheCount() {
        let m = model(bytes: 3_000_000, estimate: nil, count: 3)
        XCTAssertEqual(m.hubDetail, WheelModel.sizeText(3_000_000) + " · 3 files")
    }

    private final class Counts: @unchecked Sendable {
        private let lock = NSLock()
        private var map: [FileFormat: Int] = [:]
        func bump(_ f: FileFormat) { lock.lock(); map[f, default: 0] += 1; lock.unlock() }
        func count(_ f: FileFormat) -> Int { lock.lock(); defer { lock.unlock() }; return map[f] ?? 0 }
    }

    func testSelectingAFormatStartsAnEstimateAndShowsIt() async {
        let m = model(bytes: 1_100_000, estimate: { _ in
            try? await Task.sleep(nanoseconds: 150_000_000)
            return 340_000
        })
        m.selected = 0
        XCTAssertEqual(m.hubDetail, "…")                        // started by the selection itself
        let running = m.requestEstimate(for: formats[0])
        XCTAssertNotNil(running)                                // the already-running task
        await running?.value
        XCTAssertEqual(m.hubTitle, formats[0].displayName)
        XCTAssertEqual(m.hubDetail, "~" + WheelModel.sizeText(340_000))
    }

    func testEstimateIsComputedExactlyOnceAndCached() async {
        let counts = Counts()
        let m = model(bytes: 1000, estimate: { f in
            counts.bump(f)
            try? await Task.sleep(nanoseconds: 50_000_000)
            return 10
        })
        m.selected = 0
        let first = m.requestEstimate(for: formats[0])
        XCTAssertNotNil(first)
        XCTAssertTrue(m.requestEstimate(for: formats[0]) == first)   // still running: same task
        await first?.value
        XCTAssertEqual(counts.count(formats[0]), 1)
        XCTAssertEqual(m.estimates[formats[0]], 10)
        m.selected = 1
        await m.requestEstimate(for: formats[1])?.value
        XCTAssertEqual(counts.count(formats[1]), 1)
        m.selected = nil; m.selected = 0
        XCTAssertNil(m.requestEstimate(for: formats[0]))        // cached: no new task
        XCTAssertEqual(counts.count(formats[0]), 1)
    }

    func testFailedEstimatePublishesAndFallsBackToTheSourceSize() async {
        let m = model(bytes: 5000, estimate: { _ in
            try? await Task.sleep(nanoseconds: 50_000_000)
            return nil
        })
        var changes = 0
        let sub = m.objectWillChange.sink { changes += 1 }
        m.selected = 0
        XCTAssertEqual(m.hubDetail, "…")
        let before = changes
        await m.requestEstimate(for: formats[0])?.value
        XCTAssertGreaterThan(changes, before)                   // completion notifies observers
        XCTAssertEqual(m.hubDetail, WheelModel.sizeText(5000))
        sub.cancel()
    }

    func testTitleIsShapeshiftWithoutASourceFormat() {
        let m = WheelModel(style: .twoRings, formats: formats, tools: tools, fileCount: 2,
                           outcome: WheelOutcomeSource(sourceFormat: nil, sourceBytes: nil, estimate: nil))
        XCTAssertEqual(m.hubTitle, "Shapeshift")
    }

    func testMissingOrFailingEstimateFallsBackToTheSourceSize() async {
        let none = model(bytes: 5000, estimate: nil)
        none.selected = 0
        XCTAssertEqual(none.hubDetail, WheelModel.sizeText(5000))
        let failing = model(bytes: 5000, estimate: { _ in nil })
        failing.selected = 0
        await failing.requestEstimate(for: formats[0])?.value
        XCTAssertEqual(failing.hubDetail, WheelModel.sizeText(5000))
        XCTAssertNil(failing.requestEstimate(for: formats[0]))       // failure is remembered
    }

    func testToolAndCategoryHighlights() {
        let m = model(bytes: 5000, estimate: nil)
        m.selected = formats.count
        XCTAssertEqual(m.hubTitle, tools[0].title)
        XCTAssertEqual(m.hubDetail, "Edit")
    }

    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var conts: [CheckedContinuation<Void, Never>] = []
        private var open = false
        func wait() async {
            await withCheckedContinuation { c in
                lock.lock()
                if open { lock.unlock(); c.resume() } else { conts.append(c); lock.unlock() }
            }
        }
        func release() {
            lock.lock(); open = true; let cs = conts; conts = []; lock.unlock()
            cs.forEach { $0.resume() }
        }
    }

    func testMovingOnCancelsTheStaleEstimateAndNeverPublishesIt() async {
        let gate = Gate()
        let m = model(bytes: 5000, estimate: { f in
            if f == self.formats[0] { await gate.wait() }
            return 77
        })
        m.selected = 0
        let stale = m.requestEstimate(for: formats[0])
        m.selected = 1
        gate.release()
        await stale?.value
        XCTAssertNil(m.estimates[formats[0]])
        await m.requestEstimate(for: formats[1])?.value
        XCTAssertEqual(m.estimates[formats[1]], 77)
        m.selected = 0                                          // not failed: it can be requested again
        XCTAssertNotNil(m.requestEstimate(for: formats[0]))
        m.cancelWork()
    }

    func testCancelWorkStopsPublishing() async {
        let gate = Gate()
        let m = model(bytes: 5000, estimate: { _ in await gate.wait(); return 5 })
        m.selected = 0
        let running = m.requestEstimate(for: formats[0])
        m.cancelWork()
        gate.release()
        await running?.value
        XCTAssertTrue(m.estimates.isEmpty)
    }

    func testSourceSizeResolvesAsynchronouslyAndIsShownOnceKnown() async {
        let gate = Gate()
        let source = WheelOutcomeSource(sourceFormat: .png, sourceBytes: nil, estimate: nil,
                                        sourceBytesProvider: { await gate.wait(); return 2_000_000 })
        let m = WheelModel(style: .twoRings, formats: formats, tools: tools, fileCount: 1, outcome: source)
        XCTAssertEqual(m.hubDetail, "1 file")                   // never blocks while unknown
        gate.release()
        for _ in 0..<200 where m.sourceBytes == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(m.hubDetail, WheelModel.sizeText(2_000_000))
    }
}
