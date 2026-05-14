import Foundation
import XCTest
@testable import VoiceThingCore

final class ClipCacheTests: XCTestCase {
    func testExistingCachedAudioURLIsUsedBeforeDownload() async throws {
        let cachedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try Data("cached".utf8).write(to: cachedURL)
        defer { try? FileManager.default.removeItem(at: cachedURL) }

        let clip = MemeClip(
            id: "clip-1",
            name: "Cached",
            soundURL: URL(string: "https://example.com/should-not-download.m4a")!,
            cachedAudioURL: cachedURL
        )

        let result = try await ClipCache().cachedAudioFile(for: clip)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
    }

    func testCommonAudioFormatsArePastedWithoutM4AConversion() {
        XCTAssertTrue(ClipCache.shouldPasteOriginal(extension: "mp3"))
        XCTAssertTrue(ClipCache.shouldPasteOriginal(extension: "m4a"))
        XCTAssertTrue(ClipCache.shouldPasteOriginal(extension: "opus"))
        XCTAssertFalse(ClipCache.shouldPasteOriginal(extension: "webm"))
    }
}
