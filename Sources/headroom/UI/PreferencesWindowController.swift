import SwiftUI
import AppKit

/// Standalone window for Preferences — avoids the broken `.sheet` from MenuBarExtra.
///
/// A `MenuBarExtra` popover can't host sheets because it's a transient accessory
/// panel, not a full window. This class creates a proper NSWindow that *can*
/// accept keyboard focus for text fields and doesn't lock up the menu bar.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var service: QuotaPollingService
    private var hostingView: NSView?

    init(service: QuotaPollingService) {
        self.service = service
        super.init()
    }

    /// Show the preferences window, creating it if needed.
    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PreferencesView(service: service) {
            self.close()
        }

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame.size = hosting.fittingSize

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
                           styleMask: [.titled, .closable, .miniaturizable],
                           backing: .buffered,
                           defer: false)
        win.title = "headroom Preferences"
        win.contentView = hosting
        win.center()
        win.delegate = self
        win.isReleasedWhenClosed = false

        self.window = win
        self.hostingView = hosting
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        hostingView = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingView = nil
    }
}
