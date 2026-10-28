import AVFoundation
import Foundation

public struct AudioRecordings {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceThing/Audio Recordings", isDirectory: true)
    }

    public func clips() -> [MemeClip] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent > $1.lastPathComponent }.map {
            MemeClip(id: $0.lastPathComponent, name: $0.deletingPathExtension().lastPathComponent,
                     soundURL: $0, category: "Audio recording", cachedAudioURL: $0)
        }
    }

    public func newURL(name: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let date = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted))
        return directory.appendingPathComponent("\(date) \(Filename.safeComponent(name)) \(UUID().uuidString.prefix(4))").appendingPathExtension("m4a")
    }

    public func save(_ source: URL, name: String) throws -> URL {
        let destination = try newURL(name: name)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    public func remove(_ clip: MemeClip) throws {
        guard clip.soundURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == directory.resolvingSymlinksInPath().standardizedFileURL.path else { return }
        try FileManager.default.removeItem(at: clip.soundURL)
    }
}

@MainActor
public final class MicrophoneRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    public var onFinish: ((URL?, Error?) -> Void)?

    public func start(at url: URL) async throws {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw RecordingError.microphoneDenied
        }
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000
        ])
        recorder.delegate = self
        guard recorder.record(forDuration: 300) else { throw RecordingError.couldNotRecord }
        self.recorder = recorder
    }

    public func stop() { recorder?.stop() }

    public func cancel() {
        recorder?.delegate = nil
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
    }

    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor [weak self] in
            self?.recorder = nil
            if !flag { try? FileManager.default.removeItem(at: url) }
            self?.onFinish?(flag ? url : nil, flag ? nil : RecordingError.couldNotRecord)
        }
    }

    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.cancel()
            self?.onFinish?(nil, error ?? RecordingError.couldNotRecord)
        }
    }
}

public enum RecordingError: LocalizedError {
    case microphoneDenied, couldNotRecord, routeUnavailable

    public var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "Allow VoiceThing microphone access in System Settings → Privacy & Security → Microphone."
        case .couldNotRecord: return "The recording could not be completed. Check your audio input and try again."
        case .routeUnavailable: return "Install VoiceThing Microphone from Settings, then try again."
        }
    }
}
