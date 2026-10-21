import XCTest
import AppKit
@testable import ShapeshiftApp

final class SettingsTests: XCTestCase {
    // One fixed suite, wiped before and after each test: cfprefsd can re-create an
    // (empty) plist lazily, so unique-per-test suite names would accumulate files.
    private let suiteName = "shapeshift-tests-settings"

    private func wipe() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    override func setUp() {
        super.setUp()
        wipe()
    }

    override func tearDown() {
        wipe()
        super.tearDown()
    }

    private func makeStore() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    func testDefaults() {
        let store = makeStore()
        XCTAssertEqual(store.triggers.convert, .shift)
        XCTAssertEqual(store.triggers.tools, [.shift, .option])
        XCTAssertEqual(store.quality, 0.85)
    }

    func testTriggersRoundTrip() {
        let store = makeStore()
        store.triggers = TriggerConfig(convert: [.control], tools: [.control, .option])
        XCTAssertEqual(store.triggers.convert, [.control])
        XCTAssertEqual(store.triggers.tools, [.control, .option])
    }

    func testInvalidTriggersAreIgnored() {
        let store = makeStore()
        store.triggers = TriggerConfig(convert: [], tools: [.option])
        XCTAssertEqual(store.triggers, .default)
        store.triggers = TriggerConfig(convert: .shift, tools: .shift)
        XCTAssertEqual(store.triggers, .default)
    }

    func testQualityIsClampedAndPersisted() {
        let store = makeStore()
        store.quality = 2
        XCTAssertEqual(store.quality, 1)
        store.quality = 0.4
        XCTAssertEqual(store.quality, 0.4)
    }

    func testMatchesIsExactAndIgnoresCapsLock() {
        XCTAssertTrue(TriggerModifiers.shift.matches([.shift]))
        XCTAssertTrue(TriggerModifiers.shift.matches([.shift, .capsLock]))
        XCTAssertFalse(TriggerModifiers.shift.matches([.shift, .option]))
        XCTAssertFalse(TriggerModifiers.shift.matches([]))
        XCTAssertTrue(TriggerModifiers([.shift, .option]).matches([.option, .shift]))
    }

    func testSymbols() {
        XCTAssertEqual(TriggerModifiers([.shift, .option]).symbols, "⌥⇧")
        XCTAssertEqual(TriggerModifiers([.control, .command]).symbols, "⌃⌘")
    }

    func testMenuStyleDefaultsToTwoRingsAndRoundTrips() {
        let store = makeStore()
        XCTAssertEqual(store.menuStyle, .twoRings)
        store.menuStyle = .splitRing
        XCTAssertEqual(makeStore().menuStyle, .splitRing)
    }

    func testUnknownMenuStyleFallsBackToTwoRings() {
        UserDefaults(suiteName: suiteName)!.set("bogus", forKey: "menuStyle")
        XCTAssertEqual(makeStore().menuStyle, .twoRings)
    }

    func testTransparencyPreviewDefaultsToFrostedAndRoundTrips() {
        let store = makeStore()
        XCTAssertEqual(store.transparencyPreview, .frosted)
        store.transparencyPreview = .checkerboard
        XCTAssertEqual(makeStore().transparencyPreview, .checkerboard)
    }

    func testUnknownTransparencyPreviewFallsBackToFrosted() {
        UserDefaults(suiteName: suiteName)!.set("bogus", forKey: "transparencyPreview")
        XCTAssertEqual(makeStore().transparencyPreview, .frosted)
    }

    func testDefaultQualityConstantIsTheStoredDefault() {
        XCTAssertEqual(SettingsStore.defaultQuality, 0.85)
        XCTAssertEqual(makeStore().quality, SettingsStore.defaultQuality)
    }

    func testEveryMenuStyleHasASummary() {
        for style in MenuStyle.allCases { XCTAssertFalse(style.summary.isEmpty, "\(style)") }
    }

    func testGlassStyleDefaultsToLiquidAndRoundTrips() {
        let store = makeStore()
        XCTAssertEqual(store.glassStyle, .liquid)
        store.glassStyle = .frosted
        XCTAssertEqual(makeStore().glassStyle, .frosted)
    }

    func testRemovedClearStyleFallsBackToLiquid() {
        UserDefaults(suiteName: suiteName)!.set("clear", forKey: SettingsStore.glassStyleKey)
        XCTAssertEqual(makeStore().glassStyle, .liquid)
    }

    func testUnknownGlassStyleFallsBackToLiquid() {
        UserDefaults(suiteName: suiteName)!.set("bogus", forKey: SettingsStore.glassStyleKey)
        XCTAssertEqual(makeStore().glassStyle, .liquid)
    }

    func testSelectionColourDefaultsAndRoundTrips() {
        let store = makeStore()
        XCTAssertEqual(store.selectionColorMode, .accent)
        XCTAssertEqual(store.selectionColorHex, SettingsStore.defaultSelectionHex)
        store.selectionColorMode = .custom
        store.selectionColorHex = "#FF8800"
        XCTAssertEqual(makeStore().selectionColorMode, .custom)
        XCTAssertEqual(makeStore().selectionColorHex, "#FF8800")
        UserDefaults(suiteName: suiteName)!.set("bogus", forKey: SettingsStore.selectionColorModeKey)
        XCTAssertEqual(makeStore().selectionColorMode, .accent)
    }
}
