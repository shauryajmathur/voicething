import AppKit
import ApplicationServices
import Foundation

public final class PasteService {
    public init() {}

    public func copyAndPaste(audioFile: URL, into targetApplication: NSRunningApplication?) throws {
        copy(audioFile: audioFile)

        guard accessibilityTrusted(prompt: true) else {
            throw AppError.accessibilityPermissionNeeded
        }

        targetApplication?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            Self.postPasteShortcut()
        }
    }

    public func copy(audioFile: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let item = audioPasteboardItem(for: audioFile), pasteboard.writeObjects([item]) {
            return
        }

        let wroteObject = pasteboard.writeObjects([audioFile as NSURL])
        if !wroteObject {
            pasteboard.setString(audioFile.absoluteString, forType: .fileURL)
            pasteboard.setString(audioFile.path, forType: .string)
        }
    }

    public func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func postPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeV = CGKeyCode(9)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func audioPasteboardItem(for audioFile: URL) -> NSPasteboardItem? {
        guard let audioData = try? Data(contentsOf: audioFile), audioData.count <= 25 * 1024 * 1024 else {
            return nil
        }

        let item = NSPasteboardItem()
        item.setString(audioFile.absoluteString, forType: .fileURL)
        item.setString(audioFile.path, forType: .string)

        for type in pasteboardTypes(for: audioFile) {
            item.setData(audioData, forType: type)
        }

        return item
    }

    private func pasteboardTypes(for audioFile: URL) -> [NSPasteboard.PasteboardType] {
        switch audioFile.pathExtension.lowercased() {
        case "mp3":
            return [
                NSPasteboard.PasteboardType("public.mp3"),
                NSPasteboard.PasteboardType("audio/mpeg"),
                NSPasteboard.PasteboardType("public.audio")
            ]
        case "m4a":
            return [
                NSPasteboard.PasteboardType("com.apple.m4a-audio"),
                NSPasteboard.PasteboardType("public.mpeg-4-audio"),
                NSPasteboard.PasteboardType("audio/mp4"),
                NSPasteboard.PasteboardType("public.audio")
            ]
        case "aac":
            return [
                NSPasteboard.PasteboardType("public.aac-audio"),
                NSPasteboard.PasteboardType("audio/aac"),
                NSPasteboard.PasteboardType("public.audio")
            ]
        case "opus":
            return [
                NSPasteboard.PasteboardType("org.xiph.opus"),
                NSPasteboard.PasteboardType("audio/ogg"),
                NSPasteboard.PasteboardType("public.audio")
            ]
        case "ogg", "oga":
            return [
                NSPasteboard.PasteboardType("org.xiph.ogg"),
                NSPasteboard.PasteboardType("audio/ogg"),
                NSPasteboard.PasteboardType("public.audio")
            ]
        default:
            return [NSPasteboard.PasteboardType("public.audio")]
        }
    }
}
