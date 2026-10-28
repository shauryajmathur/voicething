import AppKit
import XCTest
@testable import VoiceThingCore

@MainActor
final class AudioAccessServiceTests: XCTestCase {
    func testAudioCopyPublishesAFileInsteadOfPathText() throws {
        let board = NSPasteboard(name: NSPasteboard.Name("VoiceThingTests-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceThing Clipboard \(UUID().uuidString).m4a")
        try Data("fixture".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        try AudioAccessService(pasteboard: board).copy(audioFile: file)
        XCTAssertTrue(board.types?.contains(.fileURL) == true)
        XCTAssertEqual(board.data(forType: NSPasteboard.PasteboardType("public.audio")), Data("fixture".utf8))
        XCTAssertNil(board.string(forType: .string))
        let copied = board.readObjects(forClasses: [NSURL.self])?.first as? URL
        XCTAssertEqual(copied?.resolvingSymlinksInPath().path, file.resolvingSymlinksInPath().path)
    }
}
