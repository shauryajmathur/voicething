import Foundation

public struct MyInstantsClient {
    public var baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://www.myinstants.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func searchClips(query: String, quantity: Int = 36) async throws -> [MemeClip] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var components = URLComponents(url: baseURL.appendingPathComponent("en/search/"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "name", value: trimmedQuery)]
        guard let url = components?.url else { throw AppError.invalidClipURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) VoiceThing/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }

        switch http.statusCode {
        case 200:
            break
        default:
            throw AppError.badStatus(http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw AppError.invalidResponse
        }

        return Self.parseSearchResults(html: html, baseURL: baseURL, limit: quantity)
    }

    public static func parseSearchResults(html: String, baseURL: URL, limit: Int = 36) -> [MemeClip] {
        let chunks = html.components(separatedBy: #"<div class="instant">"#).dropFirst()
        var results: [MemeClip] = []
        var seen = Set<String>()

        for chunk in chunks {
            guard let soundPath = firstMatch(in: chunk, pattern: #"play\('([^']+)'"#, group: 1),
                  let soundURL = URL(string: soundPath, relativeTo: baseURL)?.absoluteURL,
                  let slug = firstMatch(in: chunk, pattern: #"play\('[^']+'\s*,\s*'[^']+'\s*,\s*'([^']+)'\)"#, group: 1) else {
                continue
            }

            let title = firstMatch(in: chunk, pattern: #"<a[^>]*class="[^"]*instant-link[^"]*"[^>]*>(.*?)</a>"#, group: 1)?
                .strippingHTML
                .htmlDecoded
                .nilIfBlank
                ?? firstMatch(in: chunk, pattern: #"title="Play\s+(.*?)\s+sound""#, group: 1)?
                .htmlDecoded
                .nilIfBlank
                ?? slug.replacingOccurrences(of: "-", with: " ")

            guard !seen.contains(slug) else { continue }
            seen.insert(slug)

            let sourceURL = URL(string: "/en/instant/\(slug)/", relativeTo: baseURL)?.absoluteURL
            let tags = title
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .prefix(4)
                .map(String.init)

            results.append(
                MemeClip(
                    id: "myinstants-\(slug)",
                    name: title,
                    soundURL: soundURL,
                    thumbnailURL: nil,
                    category: "MyInstants",
                    tags: tags,
                    sourceURL: sourceURL
                )
            )

            if results.count >= limit { break }
        }

        return results
    }

    private static func firstMatch(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > group,
              let swiftRange = Range(match.range(at: group), in: text) else {
            return nil
        }

        return String(text[swiftRange])
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var strippingHTML: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    var htmlDecoded: String {
        var value = self
        let replacements = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#34;": "\"",
            "&#39;": "'",
            "&#x27;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "\\u002D": "-"
        ]

        for (encoded, decoded) in replacements {
            value = value.replacingOccurrences(of: encoded, with: decoded)
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
