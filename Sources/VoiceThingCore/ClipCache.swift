import Foundation

public final class ClipCache {
    private let fileManager: FileManager
    private let session: URLSession
    private let cacheDirectory: URL
    private let normalizer: AudioNormalizer

    public init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        normalizer: AudioNormalizer = AudioNormalizer()
    ) {
        self.fileManager = fileManager
        self.session = session
        self.normalizer = normalizer

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.cacheDirectory = appSupport
            .appendingPathComponent("VoiceThing", isDirectory: true)
            .appendingPathComponent("Clips", isDirectory: true)
    }

    public func cachedAudioFile(for clip: MemeClip) async throws -> URL {
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)

        let baseName = "\(Filename.safeComponent(clip.id))-\(Filename.safeComponent(clip.name))"
        let urlExtension = clip.soundURL.pathExtension.lowercased()
        let normalizedOutput = cacheDirectory
            .appendingPathComponent(baseName + "-normalized")
            .appendingPathExtension("m4a")

        if fileManager.fileExists(atPath: normalizedOutput.path) {
            return normalizedOutput
        }

        if Self.shouldPasteOriginal(extension: urlExtension) {
            let originalOutput = cacheDirectory
                .appendingPathComponent(baseName + "-source")
                .appendingPathExtension(urlExtension)
            if fileManager.fileExists(atPath: originalOutput.path) {
                return normalizedOrOriginal(input: originalOutput, output: normalizedOutput)
            }
        }

        if let cachedAudioURL = clip.cachedAudioURL,
           fileManager.fileExists(atPath: cachedAudioURL.path),
           !isStaleConvertedCache(cachedAudioURL, for: clip) {
            return normalizedOrOriginal(input: cachedAudioURL, output: normalizedOutput)
        }

        let preferredOutput = cacheDirectory.appendingPathComponent(baseName).appendingPathExtension("m4a")
        if fileManager.fileExists(atPath: preferredOutput.path), !Self.shouldPasteOriginal(extension: urlExtension) {
            return normalizedOrOriginal(input: preferredOutput, output: normalizedOutput)
        }

        let (downloadedURL, response) = try await session.download(from: clip.soundURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.downloadFailed
        }

        let sourceExtension = sourceExtension(for: clip.soundURL, response: http)
        let sourceFile = cacheDirectory
            .appendingPathComponent(baseName + "-source")
            .appendingPathExtension(sourceExtension)

        removeIfExists(sourceFile)
        try fileManager.moveItem(at: downloadedURL, to: sourceFile)

        if Self.shouldPasteOriginal(extension: sourceExtension) {
            return normalizedOrOriginal(input: sourceFile, output: normalizedOutput)
        }

        if sourceExtension.lowercased() == "m4a" {
            removeIfExists(preferredOutput)
            try fileManager.copyItem(at: sourceFile, to: preferredOutput)
            return normalizedOrOriginal(input: preferredOutput, output: normalizedOutput)
        }

        do {
            try convertToM4A(input: sourceFile, output: preferredOutput)
            return normalizedOrOriginal(input: preferredOutput, output: normalizedOutput)
        } catch {
            return normalizedOrOriginal(input: sourceFile, output: normalizedOutput)
        }
    }

    public static func shouldPasteOriginal(extension pathExtension: String) -> Bool {
        switch pathExtension.lowercased() {
        case "mp3", "m4a", "aac", "opus", "ogg", "oga", "wav":
            return true
        default:
            return false
        }
    }

    private func sourceExtension(for url: URL, response: HTTPURLResponse) -> String {
        let pathExtension = url.pathExtension.lowercased()
        if !pathExtension.isEmpty {
            return pathExtension
        }

        switch response.value(forHTTPHeaderField: "Content-Type")?.lowercased().split(separator: ";").first {
        case "audio/mp4", "audio/x-m4a":
            return "m4a"
        case "audio/mpeg", "audio/mp3":
            return "mp3"
        case "audio/aac":
            return "aac"
        case "audio/wav", "audio/x-wav", "audio/wave":
            return "wav"
        case "audio/ogg":
            return "ogg"
        case "audio/webm":
            return "webm"
        default:
            return "mp3"
        }
    }

    private func convertToM4A(input: URL, output: URL) throws {
        removeIfExists(output)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "m4af",
            "-d", "aac",
            input.path,
            output.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0, fileManager.fileExists(atPath: output.path) else {
            throw AppError.conversionFailed
        }
    }

    private func removeIfExists(_ url: URL) {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func normalizedOrOriginal(input: URL, output: URL) -> URL {
        do {
            return try normalizer.normalizedFile(input: input, output: output)
        } catch {
            return input
        }
    }

    private func isStaleConvertedCache(_ cachedAudioURL: URL, for clip: MemeClip) -> Bool {
        let sourceExtension = clip.soundURL.pathExtension.lowercased()
        guard Self.shouldPasteOriginal(extension: sourceExtension) else { return false }
        return cachedAudioURL.pathExtension.lowercased() != sourceExtension
    }
}
