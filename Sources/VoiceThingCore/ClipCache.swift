import Foundation

public actor ClipCache {
    private let fileManager: FileManager
    private let session: URLSession
    private let normalizer: AudioNormalizer
    private let root: URL
    private let temporaryRoot: URL

    public init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        normalizer: AudioNormalizer = AudioNormalizer(),
        root: URL? = nil,
        temporaryRoot: URL? = nil
    ) {
        self.fileManager = fileManager
        self.session = session
        self.normalizer = normalizer
        self.root = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceThing/Clips", isDirectory: true)
        self.temporaryRoot = temporaryRoot ?? fileManager.temporaryDirectory
            .appendingPathComponent("VoiceThing/Clips", isDirectory: true)
    }

    public func cachedAudioFile(for clip: MemeClip, retain: Bool = false) async throws -> URL {
        if clip.soundURL.isFileURL { return clip.soundURL }
        let directory = retain ? root : temporaryRoot
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        prune(directory, limit: retain ? 160_000_000 : 64_000_000, expires: retain ? nil : 86_400)
        let baseName = "\(Filename.safeComponent(clip.id))-\(Filename.safeComponent(clip.name))"
        let output = directory.appendingPathComponent(baseName).appendingPathExtension("m4a")
        if fileManager.fileExists(atPath: output.path) { return output }

        if let cached = clip.cachedAudioURL, fileManager.fileExists(atPath: cached.path) {
            return try normalizer.normalizedFile(input: cached, output: output)
        }
        var request = URLRequest(url: clip.soundURL)
        request.timeoutInterval = 25
        let (download, response) = try await session.download(for: request)
        defer { try? fileManager.removeItem(at: download) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let size = try download.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 32 * 1024 * 1024 else { throw AppError.downloadFailed }
        do {
            return try normalizer.normalizedFile(input: download, output: output)
        } catch {
            try? fileManager.removeItem(at: output)
            throw error
        }
    }

    public func removeCachedFiles(for clip: MemeClip) {
        let prefix = "\(Filename.safeComponent(clip.id))-\(Filename.safeComponent(clip.name))"
        for directory in [root, temporaryRoot] {
            guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.hasPrefix(prefix + ".") || file.lastPathComponent.hasPrefix(prefix + "-") {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func clearRetainedAudio() throws {
        if fileManager.fileExists(atPath: root.path) { try fileManager.removeItem(at: root) }
    }

    public func pruneExpiredAudio() {
        prune(temporaryRoot, limit: 64_000_000, expires: 86_400)
    }

    private func prune(_ directory: URL, limit: Int, expires: TimeInterval?) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(0) { $0 + $1.1 }
        for (url, size, modified) in entries {
            if total > limit || expires.map({ Date().timeIntervalSince(modified) > $0 }) == true {
                if (try? fileManager.removeItem(at: url)) != nil { total -= size }
            }
        }
    }
}
