import XCTest
@testable import VoiceThingCore

final class VoiceMessageServiceTests: XCTestCase {
    @MainActor
    func testInstagramConversationURL() {
        XCTAssertNotNil(VoiceMessageService.conversationURL("https://www.instagram.com/direct/t/12345/"))
        for invalid in ["https://www.instagram.com/", "https://www.instagram.com/direct/inbox/", "https://www.instagram.com/direct/t/", "https://www.instagram.com.attacker.test/direct/t/123/", "http://www.instagram.com/direct/t/123/", "https://web.whatsapp.com/"] {
            XCTAssertNil(VoiceMessageService.conversationURL(invalid), invalid)
        }
    }
    @MainActor
    func testOnlyWhatsAppWebUsesFilePaste() throws {
        for value in ["https://web.whatsapp.com/", "https://web.whatsapp.com/?phone=123"] {
            XCTAssertTrue(VoiceMessageService.supportsFilePaste(try XCTUnwrap(URL(string: value))), value)
        }
        for value in ["https://www.instagram.com/direct/t/123/", "https://chat.google.com/", "https://whatsapp.com/", "https://web.whatsapp.com.attacker.test/", "https://web.whatsapp.com@attacker.test/", "http://web.whatsapp.com/"] {
            XCTAssertFalse(VoiceMessageService.supportsFilePaste(try XCTUnwrap(URL(string: value))), value)
        }
    }
}
