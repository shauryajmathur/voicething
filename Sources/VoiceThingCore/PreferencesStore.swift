import Foundation

public final class PreferencesStore {
    private enum Key {
        static let favorites = "favorites"
        static let recents = "recents"
        static let shortcut = "globalShortcut"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var favorites: [MemeClip] {
        get { readClips(forKey: Key.favorites) }
        set { writeClips(newValue.prefix(100).map { $0 }, forKey: Key.favorites) }
    }

    public var recents: [MemeClip] {
        get { readClips(forKey: Key.recents) }
        set { writeClips(newValue.prefix(50).map { $0 }, forKey: Key.recents) }
    }

    public var globalShortcut: KeyboardShortcut {
        get {
            guard let data = defaults.data(forKey: Key.shortcut),
                  let shortcut = try? decoder.decode(KeyboardShortcut.self, from: data),
                  shortcut.isValid else {
                return .defaultShortcut
            }
            return shortcut
        }
        set {
            guard let data = try? encoder.encode(newValue) else { return }
            defaults.set(data, forKey: Key.shortcut)
        }
    }

    public func isFavorite(_ clip: MemeClip) -> Bool {
        favorites.contains { $0.id == clip.id }
    }

    @discardableResult
    public func toggleFavorite(_ clip: MemeClip) -> Bool {
        var current = favorites
        if let index = current.firstIndex(where: { $0.id == clip.id }) {
            current.remove(at: index)
            favorites = current
            return false
        }

        var stored = clip
        stored.isFavorite = true
        current.insert(stored, at: 0)
        favorites = current
        return true
    }

    public func recordRecent(_ clip: MemeClip, cachedAudioURL: URL?) {
        var stored = clip
        stored.cachedAudioURL = cachedAudioURL
        stored.isFavorite = isFavorite(clip)

        var current = recents.filter { $0.id != clip.id }
        current.insert(stored, at: 0)
        recents = current
    }

    private func readClips(forKey key: String) -> [MemeClip] {
        guard let data = defaults.data(forKey: key),
              let clips = try? decoder.decode([MemeClip].self, from: data) else {
            return []
        }
        return clips
    }

    private func writeClips(_ clips: [MemeClip], forKey key: String) {
        guard let data = try? encoder.encode(clips) else { return }
        defaults.set(data, forKey: key)
    }
}
