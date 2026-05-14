import XCTest
@testable import VoiceThingCore

final class PreferencesStoreTests: XCTestCase {
    func testGlobalShortcutPersistsAndDefaults() {
        let suiteName = "VoiceThingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.globalShortcut, .defaultShortcut)

        let custom = KeyboardShortcut(keyCode: 11, modifiers: 2_048, displayName: "Command+B")
        store.globalShortcut = custom

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.globalShortcut, custom)
    }
}
