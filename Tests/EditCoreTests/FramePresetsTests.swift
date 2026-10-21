import XCTest
@testable import EditCore

final class FramePresetsTests: XCTestCase {
    private var suiteName = ""
    private func makeStore() -> FramePresetStore {
        suiteName = "shapeshift-edit-presets-tests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return FramePresetStore(defaults: defaults)
    }
    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testBuiltInsExistAndAreFlagged() {
        let store = makeStore()
        XCTAssertEqual(store.all.map(\.id), ["builtin.clean", "builtin.window", "builtin.floating"])
        XCTAssertTrue(store.all.allSatisfy(\.isBuiltIn))
        XCTAssertTrue(store.preset(id: "builtin.window")!.style.windowChrome)
        XCTAssertEqual(store.defaultPreset.id, "builtin.clean")
    }

    func testAddPersistsAcrossStoreInstances() {
        let store = makeStore()
        var style = FrameStyle(); style.cornerRadius = 33
        let added = store.add(name: "Mine", style: style)
        XCTAssertFalse(added.isBuiltIn)
        let again = FramePresetStore(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(again.userPresets.map(\.name), ["Mine"])
        XCTAssertEqual(again.preset(id: added.id)?.style.cornerRadius, 33)
        XCTAssertEqual(again.all.count, 4)
    }

    func testRenameAndDeleteOnlyAffectUserPresets() {
        let store = makeStore()
        let mine = store.add(name: "Mine", style: FrameStyle())
        store.rename(id: mine.id, to: "Renamed")
        XCTAssertEqual(store.preset(id: mine.id)?.name, "Renamed")
        store.rename(id: "builtin.clean", to: "Hacked")
        XCTAssertEqual(store.preset(id: "builtin.clean")?.name, "Clean card")
        store.delete(id: "builtin.clean")
        XCTAssertNotNil(store.preset(id: "builtin.clean"))
        store.delete(id: mine.id)
        XCTAssertNil(store.preset(id: mine.id))
    }

    func testEmptyNamesAreIgnored() {
        let store = makeStore()
        let mine = store.add(name: "Mine", style: FrameStyle())
        store.rename(id: mine.id, to: "   ")
        XCTAssertEqual(store.preset(id: mine.id)?.name, "Mine")
        XCTAssertEqual(store.add(name: "  ", style: FrameStyle()).name, "Untitled")
    }

    func testDefaultSelectionPersistsAndFallsBack() {
        let store = makeStore()
        let mine = store.add(name: "Mine", style: FrameStyle())
        store.setDefault(id: mine.id)
        XCTAssertEqual(FramePresetStore(defaults: UserDefaults(suiteName: suiteName)!).defaultPreset.id, mine.id)
        store.delete(id: mine.id)
        XCTAssertEqual(store.defaultPreset.id, "builtin.clean")
        store.setDefault(id: "does-not-exist")
        XCTAssertEqual(store.defaultPreset.id, "builtin.clean")
    }
}
