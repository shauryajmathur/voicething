import XCTest
@testable import VoiceThingCore

final class FilenameTests: XCTestCase {
    func testSafeComponentKeepsPortableCharacters() {
        XCTAssertEqual(Filename.safeComponent("hello world!!!"), "hello-world")
        XCTAssertEqual(Filename.safeComponent("  wow_ok-123  "), "wow_ok-123")
        XCTAssertEqual(Filename.safeComponent(""), "clip")
    }
}
