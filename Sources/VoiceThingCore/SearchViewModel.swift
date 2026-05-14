import AppKit
import Foundation

@MainActor
public final class SearchViewModel: ObservableObject {
    public enum ViewState: Equatable {
        case idle
        case searching
        case ready
        case empty
        case failed(String)
    }

    @Published public var query = ""
    @Published public private(set) var clips: [MemeClip] = []
    @Published public private(set) var favorites: [MemeClip] = []
    @Published public private(set) var recents: [MemeClip] = []
    @Published public private(set) var state: ViewState = .idle
    @Published public var showSettings = false
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var busyClipID: String?
    @Published public var selectedIndex = 0
    @Published public var shortcut: KeyboardShortcut

    public var onDismiss: (() -> Void)?
    public var onShortcutChange: ((KeyboardShortcut) -> Void)?

    private let client: MyInstantsClient
    private let preferences: PreferencesStore
    private let cache: ClipCache
    private let pasteService: PasteService
    private let previewer: AudioPreviewer

    private var searchTask: Task<Void, Never>?
    private var targetApplication: NSRunningApplication?

    public init(
        client: MyInstantsClient = MyInstantsClient(),
        preferences: PreferencesStore = PreferencesStore(),
        cache: ClipCache = ClipCache(),
        pasteService: PasteService = PasteService(),
        previewer: AudioPreviewer? = nil
    ) {
        self.client = client
        self.preferences = preferences
        self.cache = cache
        self.pasteService = pasteService
        self.previewer = previewer ?? AudioPreviewer()
        self.shortcut = preferences.globalShortcut
        refreshStoredClips()
    }

    public var displayedClips: [MemeClip] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return deduped(favorites + recents)
        }
        return clips
    }

    public func prepareForPresentation(targetApplication: NSRunningApplication?) {
        self.targetApplication = targetApplication
        statusMessage = nil
        selectedIndex = 0
        refreshStoredClips()

        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleSearch()
        }
    }

    public func queryDidChange() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        statusMessage = nil

        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            clips = []
            state = displayedClips.isEmpty ? .idle : .ready
            selectedIndex = 0
            return
        }

        scheduleSearch()
    }

    public func scheduleSearch() {
        searchTask?.cancel()
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query: searchQuery)
        }
    }

    public func toggleFavorite(_ clip: MemeClip) {
        let isFavorite = preferences.toggleFavorite(clip)
        refreshStoredClips()

        clips = clips.map { existing in
            guard existing.id == clip.id else { return existing }
            var updated = existing
            updated.isFavorite = isFavorite
            return updated
        }
    }

    public func togglePreview(_ clip: MemeClip) {
        previewer.togglePreview(for: clip)
    }

    public func isPreviewing(_ clip: MemeClip) -> Bool {
        previewer.playingClipID == clip.id
    }

    public func isBusy(_ clip: MemeClip) -> Bool {
        busyClipID == clip.id
    }

    public func select(_ clip: MemeClip) {
        Task {
            await insert(clip)
        }
    }

    public func selectHighlighted() {
        let items = displayedClips
        guard items.indices.contains(selectedIndex), busyClipID == nil else { return }
        select(items[selectedIndex])
    }

    public func moveSelection(delta: Int) {
        let count = displayedClips.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    public func dismiss() {
        previewer.stop()
        onDismiss?()
    }

    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    public func openSoundSource() {
        guard let url = URL(string: "https://www.myinstants.com/en/categories/memes/") else { return }
        NSWorkspace.shared.open(url)
    }

    public func setShortcut(_ shortcut: KeyboardShortcut) {
        guard shortcut.isValid else {
            statusMessage = "Shortcut needs a modifier"
            return
        }

        self.shortcut = shortcut
        preferences.globalShortcut = shortcut
        onShortcutChange?(shortcut)
        statusMessage = "Shortcut: \(shortcut.displayName)"
    }

    public func resetShortcut() {
        setShortcut(.defaultShortcut)
    }

    public func quit() {
        NSApp.terminate(nil)
    }

    private func runSearch(query: String) async {
        state = .searching
        selectedIndex = 0

        do {
            let results = try await client.searchClips(query: query)
            guard !Task.isCancelled else { return }

            clips = decorate(results)
            state = clips.isEmpty ? .empty : .ready
        } catch {
            guard !Task.isCancelled else { return }
            clips = []
            state = .failed(error.localizedDescription)
        }
    }

    private func insert(_ clip: MemeClip) async {
        previewer.stop()
        busyClipID = clip.id
        statusMessage = "Preparing"

        do {
            let fileURL = try await cache.cachedAudioFile(for: clip)
            preferences.recordRecent(clip, cachedAudioURL: fileURL)
            refreshStoredClips()

            if let targetApplication {
                try pasteService.copyAndPaste(audioFile: fileURL, into: targetApplication)
                dismiss()
            } else {
                pasteService.copy(audioFile: fileURL)
                statusMessage = "Copied"
            }
        } catch {
            statusMessage = error.localizedDescription
        }

        busyClipID = nil
    }

    private func refreshStoredClips() {
        let recentCache = Dictionary(uniqueKeysWithValues: preferences.recents.compactMap { clip in
            clip.cachedAudioURL.map { (clip.id, $0) }
        })

        favorites = preferences.favorites.map { clip in
            var updated = clip
            updated.isFavorite = true
            updated.cachedAudioURL = clip.cachedAudioURL ?? recentCache[clip.id]
            return updated
        }

        recents = preferences.recents.map { clip in
            var updated = clip
            updated.isFavorite = preferences.isFavorite(clip)
            return updated
        }
    }

    private func decorate(_ clips: [MemeClip]) -> [MemeClip] {
        let cachedByID = Dictionary(uniqueKeysWithValues: recents.compactMap { clip in
            clip.cachedAudioURL.map { (clip.id, $0) }
        })

        return clips.map { clip in
            var updated = clip
            updated.isFavorite = preferences.isFavorite(clip)
            updated.cachedAudioURL = cachedByID[clip.id]
            return updated
        }
    }

    private func deduped(_ clips: [MemeClip]) -> [MemeClip] {
        var seen = Set<String>()
        return clips.filter { clip in
            if seen.contains(clip.id) { return false }
            seen.insert(clip.id)
            return true
        }
    }
}
