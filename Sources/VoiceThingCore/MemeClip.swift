import Foundation

public struct MemeClip: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let soundURL: URL
    public let thumbnailURL: URL?
    public let category: String?
    public let tags: [String]
    public var cachedAudioURL: URL?
    public var isFavorite: Bool
    public let username: String?
    public let license: String?
    public let sourceURL: URL?
    public let duration: Double?

    public init(
        id: String,
        name: String,
        soundURL: URL,
        thumbnailURL: URL? = nil,
        category: String? = nil,
        tags: [String] = [],
        cachedAudioURL: URL? = nil,
        isFavorite: Bool = false,
        username: String? = nil,
        license: String? = nil,
        sourceURL: URL? = nil,
        duration: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.soundURL = soundURL
        self.thumbnailURL = thumbnailURL
        self.category = category
        self.tags = tags
        self.cachedAudioURL = cachedAudioURL
        self.isFavorite = isFavorite
        self.username = username
        self.license = license
        self.sourceURL = sourceURL
        self.duration = duration
    }
}
