import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
public final class SearchPanelController {
    private let viewModel: SearchViewModel
    private let panel: SpotlightPanel
    private var keyMonitor: Any?
    private var modelObserver: AnyCancellable?
    private var lastHeight: CGFloat = 0
    private var dragOrigin: (mouse: NSPoint, window: NSPoint)?

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        panel = SpotlightPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: viewModel.panelHeight), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = "VoiceThing"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let host = NSHostingController(rootView: SearchPopupView(viewModel: viewModel))
        host.sizingOptions = []
        panel.contentViewController = host
        viewModel.onDismiss = { [weak panel] in panel?.orderOut(nil) }
        viewModel.onShowResult = { [weak self] in self?.show(targetApplication: nil) }
        viewModel.onPanelDrag = { [weak self] active in self?.dragPanel(active: active) }
        modelObserver = viewModel.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.updateSize() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKeyDown(event)
        }
    }

    deinit { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }
    public var isVisible: Bool { panel.isVisible }

    public func toggle(targetApplication: NSRunningApplication?) {
        if viewModel.handleSendShortcut() { return }
        if panel.isVisible { viewModel.dismiss() }
        else { show(targetApplication: targetApplication) }
    }

    public func show(targetApplication: NSRunningApplication?) {
        viewModel.prepareForPresentation(targetApplication: targetApplication)
        updateSize(animate: false)
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func updateSize(animate: Bool = true) {
        let height = viewModel.panelHeight
        guard height != lastHeight else { return }
        lastHeight = height
        let top = panel.frame.maxY
        var frame = panel.frame
        frame.size = NSSize(width: 760, height: height)
        frame.origin.y = top - height
        let shouldAnimate = animate && panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }

    private func positionPanel() {
        if let saved = UserDefaults.standard.string(forKey: "searchPanelTopLeft") {
            let point = NSPointFromString(saved)
            if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(point) }) {
                let bounds = screen.visibleFrame
                let x = min(max(point.x, bounds.minX), max(bounds.minX, bounds.maxX - panel.frame.width))
                let top = min(max(point.y, bounds.minY + panel.frame.height), bounds.maxY)
                panel.setFrameOrigin(NSPoint(x: x, y: top - panel.frame.height))
                return
            }
        }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrameOrigin(NSPoint(x: bounds.midX - panel.frame.width / 2, y: bounds.maxY - panel.frame.height - 110))
    }

    private func dragPanel(active: Bool) {
        guard active else {
            dragOrigin = nil
            UserDefaults.standard.set(NSStringFromPoint(NSPoint(x: panel.frame.minX, y: panel.frame.maxY)), forKey: "searchPanelTopLeft")
            return
        }
        let mouse = NSEvent.mouseLocation
        if dragOrigin == nil { dragOrigin = (mouse, panel.frame.origin) }
        guard let origin = dragOrigin else { return }
        panel.setFrameOrigin(NSPoint(x: origin.window.x + mouse.x - origin.mouse.x, y: origin.window.y + mouse.y - origin.mouse.y))
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if panel.firstResponder is ShortcutRecorderButton { return event }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if UInt32(event.keyCode) == viewModel.shortcut.keyCode, modifiers == viewModel.shortcut.modifiers {
            viewModel.dismiss()
            return nil
        }
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            switch event.keyCode {
            case 53:
                if viewModel.voiceClip != nil { viewModel.cancelSelection() }
                else if viewModel.showSettings { viewModel.showSettings = false }
                else { viewModel.dismiss() }
                return nil
            case 125 where !viewModel.showSettings && !viewModel.showOnboarding:
                viewModel.moveSelection(delta: 1); return nil
            case 126 where !viewModel.showSettings && !viewModel.showOnboarding:
                viewModel.moveSelection(delta: -1); return nil
            case 36, 76:
                if !viewModel.showSettings && !viewModel.showOnboarding {
                    viewModel.selectHighlighted(); return nil
                }
            default: break
            }
        }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            viewModel.showSettings.toggle(); return nil
        }
        return event
    }
}
