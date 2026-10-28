import XCTest
@testable import VoiceThingCore

final class VoiceMessageServiceTests: XCTestCase {
    @MainActor
    func testOnlyInstagramConversationsUseTheRecorder() {
        XCTAssertNotNil(VoiceMessageService.conversationURL("https://www.instagram.com/direct/t/12345/"))
        for invalid in ["https://www.instagram.com/", "https://www.instagram.com/direct/inbox/", "https://www.instagram.com/direct/t/", "https://www.instagram.com.attacker.test/direct/t/123/", "http://www.instagram.com/direct/t/123/", "https://web.whatsapp.com/"] {
            XCTAssertNil(VoiceMessageService.conversationURL(invalid), invalid)
        }
    }
}
