import Carbon
import Foundation

public struct KeyboardShortcut: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var displayName: String

    public static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
        displayName: "Option+Space"
    )

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public var isValid: Bool {
        keyCode > 0 && modifiers != 0
    }
}
