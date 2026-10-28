import AppKit
import Combine

@MainActor
public final class VoiceThingAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var sendingObserver: AnyCancellable?
    private var panelController: SearchPanelController?
    private var viewModel: SearchViewModel?
    private var hotKey: GlobalHotKey?
    private var lastExternalApplication: NSRunningApplication?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let preferences = PreferencesStore()
        let viewModel = SearchViewModel(preferences: preferences)
        self.viewModel = viewModel
        panelController = SearchPanelController(viewModel: viewModel)

        setupStatusItem()
        sendingObserver = viewModel.$isSending.sink { [weak self] sending in
            self?.statusItem?.button?.image = Self.brandImage()
            self?.statusItem?.button?.toolTip = sending ? "Preparing audio · Option–Space to cancel" : "VoiceThing · Option–Space"
        }
        observeApplicationActivation()

        hotKey = GlobalHotKey { [weak self] in
            self?.togglePanel()
        }
        if hotKey?.register(viewModel.shortcut) == false { viewModel.reportShortcutFailure() }

        viewModel.onShortcutChange = { [weak self] shortcut in
            self?.statusItem?.button?.toolTip = "VoiceThing · \(shortcut.displayName)"
            if self?.hotKey?.register(shortcut) == false { self?.viewModel?.reportShortcutFailure() }
        }
        panelController?.show(targetApplication: currentExternalApplication())
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.show(targetApplication: currentExternalApplication())
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        viewModel?.shutdown()
        hotKey?.unregister()
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    private func togglePanel() {
        let target = currentExternalApplication() ?? lastExternalApplication
        panelController?.toggle(targetApplication: target)
    }

    private static func brandImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "VoiceThingMark", withExtension: "png", subdirectory: "Brand"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = false
        return image
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.brandImage()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = statusItem
    }

    private func observeApplicationActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return
            }
            Task { @MainActor [weak self] in
                self?.lastExternalApplication = app
            }
        }
    }

    private func currentExternalApplication() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }
        return app
    }
}
