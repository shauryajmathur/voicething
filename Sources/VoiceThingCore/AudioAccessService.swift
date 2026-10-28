import AppKit
import ApplicationServices

@MainActor
public final class AudioAccessService {
    private let pasteboard: NSPasteboard
    public init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    public func copy(audioFile: URL) throws {
        pasteboard.clearContents()
        if let data = try? Data(contentsOf: audioFile, options: .mappedIfSafe), data.count <= 25 * 1024 * 1024 {
            let item = NSPasteboardItem()
            item.setString(audioFile.absoluteString, forType: .fileURL)
            let types: [String]
            switch audioFile.pathExtension.lowercased() {
            case "m4a": types = ["com.apple.m4a-audio", "public.mpeg-4-audio", "audio/mp4", "public.audio"]
            case "mp3": types = ["public.mp3", "audio/mpeg", "public.audio"]
            case "wav": types = ["com.microsoft.waveform-audio", "audio/wav", "public.audio"]
            default: types = ["public.audio"]
            }
            for type in types { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            if pasteboard.writeObjects([item]) { return }
        }
        guard pasteboard.writeObjects([audioFile as NSURL]) else { throw AppError.downloadFailed }
    }

    public func accessibilityTrusted(prompt: Bool) -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary)
    }
}
