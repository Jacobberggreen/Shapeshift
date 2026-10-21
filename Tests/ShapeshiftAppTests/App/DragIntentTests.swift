import XCTest
import AppKit
@testable import ShapeshiftApp

final class DragIntentTests: XCTestCase {
    func testDefaultTriggers() {
        let t = TriggerConfig.default
        XCTAssertEqual(DragIntent.resolve(flags: [.shift], triggers: t), .convert)
        XCTAssertEqual(DragIntent.resolve(flags: [.shift, .option], triggers: t), .tools)
        XCTAssertNil(DragIntent.resolve(flags: [], triggers: t))
        XCTAssertNil(DragIntent.resolve(flags: [.option], triggers: t))
        XCTAssertNil(DragIntent.resolve(flags: [.shift, .command], triggers: t))
    }

    func testCapsLockAndFnAreIgnored() {
        XCTAssertEqual(DragIntent.resolve(flags: [.shift, .capsLock], triggers: .default), .convert)
    }

    func testRebindableTriggers() {
        let t = TriggerConfig(convert: [.control], tools: [.control, .option])
        XCTAssertEqual(DragIntent.resolve(flags: [.control], triggers: t), .convert)
        XCTAssertEqual(DragIntent.resolve(flags: [.control, .option], triggers: t), .tools)
        XCTAssertNil(DragIntent.resolve(flags: [.shift], triggers: t))
    }
}
