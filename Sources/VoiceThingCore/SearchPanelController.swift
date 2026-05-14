import AppKit
import SwiftUI

@MainActor
public final class SearchPanelController {
    private let viewModel: SearchViewModel
    private let panel: SpotlightPanel
    private var keyMonitor: Any?

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel

        panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "VoiceThing"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = NSHostingController(rootView: SearchPopupView(viewModel: viewModel))

        viewModel.onDismiss = { [weak panel] in
            panel?.orderOut(nil)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            return self.handleKeyDown(event)
        }
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    public var isVisible: Bool {
        panel.isVisible
    }

    public func toggle(targetApplication: NSRunningApplication?) {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        show(targetApplication: targetApplication)
    }

    public func show(targetApplication: NSRunningApplication?) {
        viewModel.prepareForPresentation(targetApplication: targetApplication)
        positionPanel()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - 88
        )
        panel.setFrameOrigin(origin)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53:
            viewModel.dismiss()
            return nil
        case 125:
            viewModel.moveSelection(delta: 1)
            return nil
        case 126:
            viewModel.moveSelection(delta: -1)
            return nil
        case 36, 76:
            viewModel.selectHighlighted()
            return nil
        default:
            return event
        }
    }
}
