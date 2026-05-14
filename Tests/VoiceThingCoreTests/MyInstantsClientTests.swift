import Foundation
import XCTest
@testable import VoiceThingCore

final class MyInstantsClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSearchBuildsMyInstantsRequestAndParsesResults() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.handler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/en/search/")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "name" })?.value, "vine boom")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))

            let body = """
            <div id="instants_container">
              <div class="instants result-page">
                <div class="instant">
                  <button class="small-button" onclick="play('/media/sounds/vine-boom.mp3', 'loader-81126', 'vine-boom-sound-70972')" title="Play VINE BOOM SOUND sound" type="button"></button>
                  <a href="/en/instant/vine-boom-sound-70972/" class="instant-link link-secondary">VINE BOOM SOUND</a>
                </div>
                <div class="instant">
                  <button class="small-button" onclick="play('/media/sounds/bruh-sound-effect.mp3', 'loader-297229', 'bruh-sound-effect-26614')" title="Play BRUH sound effect! sound" type="button"></button>
                  <a href="/en/instant/bruh-sound-effect-26614/" class="instant-link link-secondary">BRUH sound effect!</a>
                </div>
              </div>
            </div>
            """

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html"]
            )!

            return (response, Data(body.utf8))
        }

        let client = MyInstantsClient(baseURL: URL(string: "https://www.myinstants.com")!, session: session)
        let clips = try await client.searchClips(query: "vine boom")

        XCTAssertEqual(clips.count, 2)
        XCTAssertEqual(clips[0].id, "myinstants-vine-boom-sound-70972")
        XCTAssertEqual(clips[0].name, "VINE BOOM SOUND")
        XCTAssertEqual(clips[0].soundURL.absoluteString, "https://www.myinstants.com/media/sounds/vine-boom.mp3")
        XCTAssertEqual(clips[0].sourceURL?.absoluteString, "https://www.myinstants.com/en/instant/vine-boom-sound-70972/")
        XCTAssertEqual(clips[0].category, "MyInstants")
    }

    func testParserDecodesHtmlEntities() {
        let html = """
        <div class="instant">
          <button class="small-button" onclick="play('/media/sounds/test.mp3', 'loader-1', 'test-sound')" title="Play Test sound" type="button"></button>
          <a href="/en/instant/test-sound/" class="instant-link link-secondary">Dog &amp; Cat &#39;Wow&#39;</a>
        </div>
        """

        let clips = MyInstantsClient.parseSearchResults(html: html, baseURL: URL(string: "https://www.myinstants.com")!)
        XCTAssertEqual(clips.first?.name, "Dog & Cat 'Wow'")
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
