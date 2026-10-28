import AppKit
import Combine
import Foundation
import OSLog

@MainActor
public final class SearchViewModel: ObservableObject {
    public enum ViewState: Equatable { case idle, searching, ready, empty, failed(String) }
    public enum Library: String, CaseIterable { case sounds = "Sounds", recordings = "Audio Recordings" }

    @Published public var query = "" { didSet { queryDidChange() } }
    @Published public private(set) var clips: [MemeClip] = []
    @Published public private(set) var favorites: [MemeClip] = []
    @Published public private(set) var recents: [MemeClip] = []
    @Published public private(set) var recordings: [MemeClip] = []
    @Published public private(set) var state: ViewState = .idle
    @Published public var showSettings = false
    @Published public var showOnboarding: Bool
    @Published public var onboardingStep = 0
    @Published public var library: Library = .sounds
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var busyClipID: String?
    @Published public var selectedIndex = 0
    @Published public var shortcut: KeyboardShortcut
    @Published public private(set) var retainsAudio: Bool
    @Published public private(set) var isRecording = false
    @Published public private(set) var isRequestingMicrophone = false
    @Published public private(set) var voiceClip: MemeClip?
    @Published public private(set) var isClearingStorage = false
    @Published public private(set) var isSending = false

    public var onDismiss: (() -> Void)?
    public var onPanelDrag: ((Bool) -> Void)?
    public var onShowResult: (() -> Void)?
    public var onShortcutChange: ((KeyboardShortcut) -> Void)?
    private let logger = Logger(subsystem: "com.voicething.app", category: "Send")
    private let client: MyInstantsClient
    private let preferences: PreferencesStore
    private let cache: ClipCache
    private let audioAccess: AudioAccessService
    private let previewer: AudioPreviewer
    private let audioRecordings = AudioRecordings()
    private let recorder = MicrophoneRecorder()
    private var previewerCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    @Published private var targetApplication: NSRunningApplication?
    private var searchCache: [String: (Date, [MemeClip])] = [:]

    public init(client: MyInstantsClient = MyInstantsClient(), preferences: PreferencesStore = PreferencesStore(), cache: ClipCache = ClipCache(), audioAccess: AudioAccessService? = nil, previewer: AudioPreviewer? = nil) {
        self.client = client
        self.preferences = preferences
        self.cache = cache
        self.audioAccess = audioAccess ?? AudioAccessService()
        self.previewer = previewer ?? AudioPreviewer()
        shortcut = preferences.globalShortcut
        retainsAudio = preferences.retainsAudio
        showOnboarding = !preferences.hasCompletedOnboarding
        previewerCancellable = self.previewer.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        favorites = retainsAudio ? preferences.favorites : []
        recents = retainsAudio ? preferences.recents : []
        refreshRecordings()
        recorder.onFinish = { [weak self] url, error in
            guard let self else { return }
            self.isRecording = false
            if url != nil {
                self.refreshRecordings()
                self.statusMessage = "Recording ready"
                self.library = .recordings
                self.query = ""
                self.selectedIndex = 0
                self.previewer.stop()
            } else { self.statusMessage = error?.localizedDescription }
        }
        Task { await cache.pruneExpiredAudio() }
    }

    public var displayedClips: [MemeClip] {
        if library == .recordings {
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            return term.isEmpty ? recordings : recordings.filter { $0.name.localizedCaseInsensitiveContains(term) }
        }
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var seen = Set<String>()
            return (favorites + recents).filter { seen.insert($0.id).inserted }
        }
        return clips
    }

    public var isExpanded: Bool { showOnboarding || showSettings || voiceClip != nil || isRecording || library == .recordings || !query.isEmpty }
    public var panelHeight: CGFloat { showOnboarding ? 470 : (isExpanded ? 540 : 78) }
    public var availableChatApplications: [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    public func chooseTargetApplication(_ application: NSRunningApplication) {
        guard !isSending, availableChatApplications.contains(where: { $0.processIdentifier == application.processIdentifier }) else { return }
        targetApplication = application
        statusMessage = nil
    }
    public var targetName: String { targetApplication?.localizedName ?? "your chat app" }
    public var hasAccessibility: Bool { audioAccess.accessibilityTrusted(prompt: false) }

    public func prepareForPresentation(targetApplication: NSRunningApplication?) {
        if let targetApplication { self.targetApplication = targetApplication }
        refreshRecordings()
        selectedIndex = 0
    }

    public func queryDidChange() {
        searchTask?.cancel()
        selectedIndex = 0
        statusMessage = nil
        guard library == .sounds else { return }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { clips = []; state = .idle; return }
        state = .searching
        searchTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            await self?.runSearch(query: term)
        }
    }

    public func changeLibrary(_ library: Library) {
        self.library = library
        query = ""
        selectedIndex = 0
    }

    private func runSearch(query: String) async {
        do {
            let results: [MemeClip]
            if let cached = searchCache[query.lowercased()], Date().timeIntervalSince(cached.0) < 300 { results = cached.1 }
            else {
                results = try await client.searchClips(query: query)
                guard !Task.isCancelled else { return }
                if searchCache.count >= 12 { searchCache.removeAll(keepingCapacity: true) }
                searchCache[query.lowercased()] = (Date(), results)
            }
            guard !Task.isCancelled else { return }
            clips = results.map { item in var item = item; item.isFavorite = favorites.contains { $0.id == item.id }; return item }
            state = clips.isEmpty ? .empty : .ready
        } catch {
            guard !Task.isCancelled else { return }
            clips = []
            state = .failed(error.localizedDescription)
        }
    }

    public func toggleFavorite(_ clip: MemeClip) {
        if let index = favorites.firstIndex(where: { $0.id == clip.id }) { favorites.remove(at: index) }
        else { var saved = clip; saved.isFavorite = true; favorites.insert(saved, at: 0) }
        if retainsAudio { preferences.favorites = favorites }
        clips = clips.map { item in var item = item; item.isFavorite = favorites.contains { $0.id == item.id }; return item }
    }

    public func togglePreview(_ clip: MemeClip) { guard !isRecording, !isSending else { return }; previewer.togglePreview(for: clip) }
    public func isPreviewing(_ clip: MemeClip) -> Bool { previewer.playingClipID == clip.id }
    public func isBusy(_ clip: MemeClip) -> Bool { busyClipID == clip.id }

    public func deleteClip(_ clip: MemeClip) {
        previewer.stop()
        do {
            if clip.soundURL.isFileURL { try audioRecordings.remove(clip); refreshRecordings() }
            else {
                favorites.removeAll { $0.id == clip.id }
                recents.removeAll { $0.id == clip.id }
                preferences.removeClip(clip)
                clips.removeAll { $0.id == clip.id }
                Task { await cache.removeCachedFiles(for: clip) }
            }
            selectedIndex = min(selectedIndex, max(displayedClips.count - 1, 0))
            statusMessage = "Removed"
        } catch { statusMessage = error.localizedDescription }
    }

    public func select(_ clip: MemeClip) {
        guard busyClipID == nil, !isRecording, !isRequestingMicrophone, !isSending else { return }
        previewer.stop()
        busyClipID = clip.id
        isSending = true
        let target = targetApplication
        actionTask = Task { [weak self] in
            guard let self else { return }
            var panelHidden = false
            defer { self.busyClipID = nil; self.isSending = false; self.actionTask = nil }
            do {
                let url = try await self.cache.cachedAudioFile(for: clip, retain: self.retainsAudio)
                try Task.checkCancellation()
                self.recordRecent(clip, url: self.retainsAudio ? url : nil)
                guard let target, !target.isTerminated else { throw AppError.targetUnavailable }
                guard self.audioAccess.accessibilityTrusted(prompt: true) else { throw AppError.accessibilityPermissionNeeded }
                self.onDismiss?()
                panelHidden = true
                target.activate(options: [])
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                let voice = VoiceMessageService()
                try await voice.prepare(audioFile: url, in: target, conversation: voice.destination(in: target))
                self.voiceClip = nil
                self.query = ""
            } catch is CancellationError {
                self.statusMessage = "Send cancelled"
            } catch {
                self.logger.error("Send failed: \(error.localizedDescription, privacy: .public)")
                self.voiceClip = clip
                self.statusMessage = error.localizedDescription
                if panelHidden { self.onShowResult?() }
            }
        }
    }

    public func chooseChatTarget(for clip: MemeClip) {
        guard busyClipID == nil, !isRecording else { return }
        voiceClip = clip
        statusMessage = nil
    }

    public func selectHighlighted() {
        guard !showOnboarding, !showSettings else { return }
        if let clip = voiceClip { select(clip); return }
        let items = displayedClips
        if items.indices.contains(selectedIndex) { select(items[selectedIndex]) }
    }

    public func moveSelection(delta: Int) { selectedIndex = min(max(selectedIndex + delta, 0), max(displayedClips.count - 1, 0)) }

    @discardableResult
    public func handleSendShortcut() -> Bool {
        guard isSending else { return false }
        actionTask?.cancel()
        return true
    }

    public func cancelSelection() {
        actionTask?.cancel()
        voiceClip = nil
        if !isSending { busyClipID = nil }
    }

    public func copyClip(_ clip: MemeClip) {
        guard busyClipID == nil else { return }
        busyClipID = clip.id
        previewer.stop()
        actionTask = Task { [weak self] in
            guard let self else { return }
            defer { self.busyClipID = nil; self.actionTask = nil }
            do {
                let url = try await cache.cachedAudioFile(for: clip, retain: retainsAudio)
                try Task.checkCancellation()
                try audioAccess.copy(audioFile: url)
                recordRecent(clip, url: retainsAudio ? url : nil)
                statusMessage = "Audio file copied"
            } catch { statusMessage = error.localizedDescription }
        }
    }

    public func saveRecording(_ clip: MemeClip) {
        guard busyClipID == nil else { return }
        busyClipID = clip.id
        actionTask = Task { [weak self] in
            guard let self else { return }
            defer { self.busyClipID = nil }
            do {
                let url = try await cache.cachedAudioFile(for: clip, retain: retainsAudio)
                try Task.checkCancellation()
                let store = audioRecordings
                _ = try await Task.detached(priority: .userInitiated) { try store.save(url, name: clip.name) }.value
                refreshRecordings()
                statusMessage = "Saved to Audio Recordings"
            } catch { statusMessage = error.localizedDescription }
        }
    }

    public func toggleRecording() {
        if isRecording { recorder.stop(); return }
        guard !isRequestingMicrophone, busyClipID == nil else { return }
        cancelSelection()
        previewer.stop()
        isRequestingMicrophone = true
        Task { [weak self] in
            guard let self else { return }
            defer { isRequestingMicrophone = false }
            do {
                let url = try audioRecordings.newURL(name: "Recording")
                try await recorder.start(at: url)
                isRecording = true
                library = .recordings
                query = ""
            } catch { statusMessage = error.localizedDescription }
        }
    }

    public func cancelRecording() { recorder.cancel(); isRecording = false }

    public func setRetention(_ enabled: Bool) {
        retainsAudio = enabled
        preferences.retainsAudio = enabled
        if enabled { preferences.favorites = favorites; preferences.recents = recents; return }
        clearStoredAudio()
    }

    public func clearStoredAudio() {
        guard !isClearingStorage, busyClipID == nil else { return }
        isClearingStorage = true
        preferences.clearHistory()
        favorites = []; recents = []
        Task {
            defer { isClearingStorage = false }
            do { try await cache.clearRetainedAudio(); statusMessage = "Cached sounds and history cleared" }
            catch { statusMessage = error.localizedDescription }
        }
    }

    public func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
        showOnboarding = false
        query = ""
    }
    public func revealRecordings() {
        do {
            try FileManager.default.createDirectory(at: audioRecordings.directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(audioRecordings.directory)
        } catch { statusMessage = error.localizedDescription }
    }
    public func openAccessibilitySettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
    public func requestAccessibility() { _ = audioAccess.accessibilityTrusted(prompt: true) }
    public func openSoundSource() { NSWorkspace.shared.open(URL(string: "https://www.myinstants.com/en/categories/memes/")!) }
    public func setShortcut(_ shortcut: KeyboardShortcut) {
        guard shortcut.isValid else { statusMessage = "Choose a key with at least one modifier"; return }
        self.shortcut = shortcut
        preferences.globalShortcut = shortcut
        onShortcutChange?(shortcut)
    }
    public func resetShortcut() { setShortcut(.defaultShortcut) }
    public func dismiss() {
        if isRecording { statusMessage = "Finish or discard your recording first"; return }
        if isRequestingMicrophone { return }
        previewer.stop()
        searchTask?.cancel()
        cancelSelection()
        onDismiss?()
    }
    public func shutdown() { recorder.cancel(); cancelSelection(); previewer.stop() }
    public func quit() { shutdown(); NSApp.terminate(nil) }
    public func reportShortcutFailure() { statusMessage = "Shortcut unavailable. Another app may be using it. Choose a different shortcut in Settings." }
    private func refreshRecordings() { recordings = audioRecordings.clips() }
    private func recordRecent(_ clip: MemeClip, url: URL?) {
        guard !clip.soundURL.isFileURL else { return }
        var stored = clip; stored.cachedAudioURL = url
        recents.removeAll { $0.id == clip.id }; recents.insert(stored, at: 0)
        recents = Array(recents.prefix(50))
        if retainsAudio { preferences.recordRecent(clip, cachedAudioURL: url) }
    }
}
