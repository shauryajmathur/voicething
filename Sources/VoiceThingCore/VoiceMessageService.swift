import AppKit
import ApplicationServices
import OSLog

@MainActor
final class VoiceMessageService {
    private let logger = Logger(subsystem: "com.voicething.app", category: "Instagram")
    private var targetWindow: AXUIElement?
    private let browserIDs: Set<String> = ["app.zen-browser.zen", "org.mozilla.firefox"]

    static func conversationURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host == "www.instagram.com",
              url.path.hasPrefix("/direct/t/"),
              !url.path.dropFirst("/direct/t/".count).trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty else { return nil }
        return url
    }

    func destination(in app: NSRunningApplication) -> URL? {
        guard browserIDs.contains(app.bundleIdentifier ?? "") else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var focused = elementAttribute(application, kAXFocusedUIElementAttribute)
        for _ in 0..<16 {
            guard let element = focused else { break }
            if let url = conversation(in: element) { return url }
            focused = elementAttribute(element, kAXParentAttribute)
        }
        guard let window = elementAttribute(application, kAXFocusedWindowAttribute) else { return nil }
        var pending = [window]
        var index = 0
        while index < pending.count && index < 1000 {
            let element = pending[index]
            index += 1
            if let url = conversation(in: element) { return url }
            if string(element, kAXRoleAttribute) == kAXMenuRole { continue }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] { pending.append(contentsOf: children) }
        }
        return nil
    }

    private func conversation(in element: AXUIElement) -> URL? {
        guard string(element, kAXRoleAttribute) == "AXWebArea" else { return nil }
        if let value = attribute(element, kAXURLAttribute) as? URL { return Self.conversationURL(value.absoluteString) }
        return Self.conversationURL(string(element, kAXURLAttribute))
    }

    func prepare(audioFile: URL, in app: NSRunningApplication, conversation: URL? = nil) async throws {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        targetWindow = elementAttribute(application, kAXFocusedWindowAttribute)
        let route = VoiceRecordingRoute()
        var recordingStarted = false
        var sent = false
        defer {
            route.stop()
            if recordingStarted, !sent, (conversation == nil || destination(in: app) == conversation),
               let close = cancelControl(in: application) {
                AXUIElementPerformAction(close, kAXPressAction as CFString)
            }
        }

        app.activate(options: [])
        try await Task.sleep(for: .milliseconds(250))
        try ensureConversation(conversation, in: app)
        guard self.recordControl(in: application) != nil else {
            throw AppError.instagramVoice("Open a chat with a voice-recording button. VoiceThing could not find this app’s recorder.")
        }
        try route.prepare(file: audioFile)
        try await Task.sleep(for: .milliseconds(400))
        let microphone = try await wait(seconds: 8) {
            try self.ensureConversation(conversation, in: app)
            return self.recordControl(in: application)
        }
        try ensureConversation(conversation, in: app)
        guard AXUIElementPerformAction(microphone, kAXPressAction as CFString) == .success else {
            throw AppError.instagramVoice("Could not start the chat’s voice recorder.")
        }
        recordingStarted = true
        _ = try await wait(seconds: 8) {
            try self.ensureConversation(conversation, in: app)
            return self.stopControl(in: application)
        }
        try await Task.sleep(for: .milliseconds(700))
        logger.info("Playing clip through virtual microphone")
        try await route.play {
            try self.ensureConversation(conversation, in: app)
        }
        try await Task.sleep(for: .milliseconds(250))
        try ensureConversation(conversation, in: app)
        guard let stop = stopControl(in: application),
              AXUIElementPerformAction(stop, kAXPressAction as CFString) == .success else {
            throw AppError.instagramVoice("Could not stop the chat’s voice recorder.")
        }
        let send = try await wait(seconds: 15) {
            try self.ensureConversation(conversation, in: app)
            return self.voicePreviewSend(in: application, instagram: conversation != nil)
        }
        try Task.checkCancellation()
        try ensureConversation(conversation, in: app)
        guard AXUIElementPerformAction(send, kAXPressAction as CFString) == .success else {
            throw AppError.instagramVoice("Could not send the Voice message.")
        }
        sent = true
        _ = try await wait(seconds: 15) {
            try self.ensureConversation(conversation, in: app)
            guard self.cancelControl(in: application) == nil else { return nil }
            return self.recordControl(in: application)
        }
        logger.info("Voice message sent")
    }

    private func ensureConversation(_ conversation: URL?, in app: NSRunningApplication) throws {
        guard !app.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              (conversation == nil || destination(in: app) == conversation),
              let window = elementAttribute(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute),
              targetWindow.map({ CFEqual($0, window) }) == true else {
            throw AppError.instagramVoice("The conversation changed. Try again.")
        }
    }

    private func recordControl(in root: AXUIElement) -> AXUIElement? {
        firstControl(["Voice Clip", "Record a voice message", "Record voice message", "Voice message", "Record audio", "Record Audio", "Audio message", "Voice Message"], in: root)
    }

    private func stopControl(in root: AXUIElement) -> AXUIElement? {
        firstControl(["Stop recording", "Stop Recording", "Stop voice recording", "Stop"], in: root)
    }

    private func cancelControl(in root: AXUIElement) -> AXUIElement? {
        firstControl(["Close Button", "Cancel recording", "Discard voice message", "Delete recording"], in: root)
    }

    private func firstControl(_ labels: [String], in root: AXUIElement) -> AXUIElement? {
        labels.lazy.compactMap { self.control($0, in: root) }.first
    }

    private func voicePreviewSend(in root: AXUIElement, instagram: Bool) -> AXUIElement? {
        guard stopControl(in: root) == nil else { return nil }
        if instagram, cancelControl(in: root) == nil || control("Play", in: root) == nil { return nil }
        return firstControl(["Send", "Send voice message", "Send audio message", "Send Audio Message"], in: root)
    }

    func wait(seconds: Double, check: () throws -> AXUIElement?) async throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            try Task.checkCancellation()
            if let result = try check() { return result }
            try await Task.sleep(for: .milliseconds(150))
        }
        throw AppError.instagramVoice("The chat did not prepare the voice clip. Close any draft and try again.")
    }

    private func control(_ label: String, in root: AXUIElement) -> AXUIElement? {
        let window = elementAttribute(root, kAXFocusedWindowAttribute) ?? root
        let elements = descendants(window)
        func matches(_ element: AXUIElement, _ name: String) -> Bool {
            guard string(element, kAXRoleAttribute) == kAXButtonRole,
                  attribute(element, kAXEnabledAttribute) as? Bool != false else { return false }
            if [string(element, kAXTitleAttribute), string(element, kAXDescriptionAttribute)].contains(name) { return true }
            let children = (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
            return children.contains { child in
                [string(child, kAXTitleAttribute), string(child, kAXDescriptionAttribute)].contains(name)
            }
        }
        let result = elements.first { matches($0, label) }
        return result
    }

    func descendants(_ root: AXUIElement) -> [AXUIElement] {
        var pending = [root]
        var result: [AXUIElement] = []
        while !pending.isEmpty && result.count < 2500 {
            let current = pending.removeLast()
            result.append(current)
            if let children = attribute(current, kAXChildrenAttribute) as? [AXUIElement] { pending.append(contentsOf: children.reversed()) }
        }
        return result
    }
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    func string(_ element: AXUIElement, _ name: String) -> String { attribute(element, name) as? String ?? "" }
}
