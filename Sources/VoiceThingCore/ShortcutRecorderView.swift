import AppKit
import Carbon
import SwiftUI

public struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut
    let onChange: (KeyboardShortcut) -> Void

    public init(shortcut: Binding<KeyboardShortcut>, onChange: @escaping (KeyboardShortcut) -> Void) {
        self._shortcut = shortcut
        self.onChange = onChange
    }

    public func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = { newShortcut in
            shortcut = newShortcut
            onChange(newShortcut)
        }
        return button
    }

    public func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
        nsView.needsDisplay = true
    }
}

public final class ShortcutRecorderButton: NSButton {
    public var shortcut: KeyboardShortcut = .defaultShortcut {
        didSet { updateTitle() }
    }
    public var onChange: ((KeyboardShortcut) -> Void)?
    private var recording = false

    public init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
        updateTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        recording = true
        title = "Press shortcut"
        window?.makeFirstResponder(self)
    }

    public override func keyDown(with event: NSEvent) {
        guard recording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            updateTitle()
            return
        }

        let carbonModifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            title = "Add modifier"
            return
        }

        let displayName = Self.displayName(for: event, carbonModifiers: carbonModifiers)
        let newShortcut = KeyboardShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers,
            displayName: displayName
        )

        recording = false
        shortcut = newShortcut
        onChange?(newShortcut)
    }

    private func updateTitle() {
        title = recording ? "Press shortcut" : shortcut.displayName
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func displayName(for event: NSEvent, carbonModifiers: UInt32) -> String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        parts.append(keyDisplayName(for: event))
        return parts.joined(separator: "+")
    }

    private static func keyDisplayName(for event: NSEvent) -> String {
        if event.keyCode == UInt16(kVK_Space) { return "Space" }
        if event.keyCode == UInt16(kVK_Return) { return "Return" }
        if event.keyCode == UInt16(kVK_Tab) { return "Tab" }
        if event.keyCode == UInt16(kVK_Delete) { return "Delete" }
        if event.keyCode >= UInt16(kVK_F1), event.keyCode <= UInt16(kVK_F20) {
            return "F\(Int(event.keyCode) - Int(kVK_F1) + 1)"
        }

        let characters = event.charactersIgnoringModifiers?.uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return characters?.isEmpty == false ? characters! : "Key \(event.keyCode)"
    }
}
