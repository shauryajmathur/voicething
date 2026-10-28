import XCTest
@testable import VoiceThingCore

final class AudioRecordingsTests: XCTestCase {
    func testExplicitSaveListsAndDeletesOnlyOwnedRecording() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data("fixture".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let store = AudioRecordings(directory: directory)
        let saved = try store.save(source, name: "A / B")
        XCTAssertEqual(store.clips().count, 1)
        XCTAssertEqual(store.clips().first?.soundURL.resolvingSymlinksInPath().path, saved.resolvingSymlinksInPath().path)
        try store.remove(MemeClip(id: "external", name: "External", soundURL: source))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        try store.remove(store.clips()[0])
        XCTAssertTrue(store.clips().isEmpty)
    }
}
