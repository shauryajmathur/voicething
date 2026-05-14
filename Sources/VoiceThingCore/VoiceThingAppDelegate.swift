import AppKit

@MainActor
public final class VoiceThingAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: SearchPanelController?
    private var hotKey: GlobalHotKey?
    private var lastExternalApplication: NSRunningApplication?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let viewModel = SearchViewModel()
        panelController = SearchPanelController(viewModel: viewModel)

        setupStatusItem()
        observeApplicationActivation()

        hotKey = GlobalHotKey { [weak self] in
            self?.togglePanel()
        }
        hotKey?.register(viewModel.shortcut)

        viewModel.onShortcutChange = { [weak self] shortcut in
            self?.hotKey?.register(shortcut)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    private func togglePanel() {
        let target = currentExternalApplication() ?? lastExternalApplication
        panelController?.toggle(targetApplication: target)
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoiceThing")
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
