import AppKit
import VoiceThingCore

@main
struct VoiceThingMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = VoiceThingAppDelegate()

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
