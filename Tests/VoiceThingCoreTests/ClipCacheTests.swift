import AVFoundation
import XCTest
@testable import VoiceThingCore

final class ClipCacheTests: XCTestCase {
    func testTemporaryPreparationDoesNotCreateRetainedLibrary() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.caf")
        try makeAudio(at: source)
        let retained = directory.appendingPathComponent("retained")
        let temporary = directory.appendingPathComponent("temporary")
        let cache = ClipCache(root: retained, temporaryRoot: temporary)
        let clip = MemeClip(id: "temporary-clip", name: "Temporary", soundURL: URL(string: "https://example.com/no-download.mp3")!, cachedAudioURL: source)
        let output = try await cache.cachedAudioFile(for: clip)
        XCTAssertEqual(output.deletingLastPathComponent().path, temporary.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: retained.path))
        XCTAssertGreaterThan(try AVAudioFile(forReading: output).length, 0)
    }

    func testRetentionAndRemovalStayInsideCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.caf")
        try makeAudio(at: source)
        let retained = directory.appendingPathComponent("retained")
        let cache = ClipCache(root: retained, temporaryRoot: directory.appendingPathComponent("temporary"))
        let clip = MemeClip(id: "clip", name: "Retained", soundURL: URL(string: "https://example.com/no-download.mp3")!, cachedAudioURL: source)
        let output = try await cache.cachedAudioFile(for: clip, retain: true)
        XCTAssertEqual(output.deletingLastPathComponent().path, retained.path)
        await cache.removeCachedFiles(for: clip)
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "Never delete an external cached URL supplied by a clip")
    }

    func testLocalRecordingsAreUsedWithoutCopying() async throws {
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try Data("fixture".utf8).write(to: local)
        defer { try? FileManager.default.removeItem(at: local) }
        let clip = MemeClip(id: "local", name: "Recording", soundURL: local)
        let output = try await ClipCache().cachedAudioFile(for: clip)
        XCTAssertEqual(output, local)
    }

    private func makeAudio(at url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)!
        buffer.frameLength = 4410
        for i in 0..<4410 { buffer.floatChannelData![0][i] = sin(Float(i) * 0.1) * 0.1 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
