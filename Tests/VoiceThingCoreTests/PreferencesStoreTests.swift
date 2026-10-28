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

    func testStorageAndOnboardingAreExplicitOptIns() {
        let suite = "VoiceThingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        XCTAssertFalse(store.retainsAudio)
        XCTAssertFalse(store.hasCompletedOnboarding)
        store.retainsAudio = true
        store.hasCompletedOnboarding = true
        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertTrue(reloaded.retainsAudio)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }

    func testOptionSpaceAndCommandAAreValidShortcuts() {
        XCTAssertTrue(KeyboardShortcut.defaultShortcut.isValid)
        XCTAssertTrue(KeyboardShortcut(keyCode: 0, modifiers: 256, displayName: "Command+A").isValid)
        XCTAssertFalse(KeyboardShortcut(keyCode: 49, modifiers: 0, displayName: "Space").isValid)
    }

    func testRemoveClipClearsFavoritesAndRecents() {
        let suiteName = "VoiceThingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let clip = MemeClip(
            id: "clip-to-delete",
            name: "Delete Me",
            soundURL: URL(string: "https://example.com/delete.mp3")!
        )

        store.favorites = [clip]
        store.recents = [clip]
        store.removeClip(clip)

        XCTAssertTrue(store.favorites.isEmpty)
        XCTAssertTrue(store.recents.isEmpty)
    }
}
