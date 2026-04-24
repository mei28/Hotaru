import AppKit
import SwiftUI

// Dedicated NSWindowController for the settings window.
//
// Why not rely on SwiftUI's `Settings { }` scene?
//   - LSUIElement apps (no Dock icon) have a nearly-empty main menu, so
//     `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)` does not
//     always reach the Settings-scene handler through the responder chain.
//   - As a result, clicking "Settings…" in the menu bar sometimes does nothing.
// -> Construct an NSWindow ourselves in AppKit and embed the SwiftUI view
//    via NSHostingController. This gives deterministic behavior.
//
// NSHostingController<Content: View>:
//   - Bridges a SwiftUI view hierarchy into an AppKit NSViewController.
//   - The SwiftUI side keeps observing Preferences via @ObservedObject as
//     usual, so passing Preferences.shared in is enough to have live updates.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    // Singleton — one settings window is enough for the whole app.
    // Swift guarantees that `static let` is constructed lazily and thread-safely
    // on first access.
    static let shared = SettingsWindowController()

    // We customize init(window:), so the designated init is private.
    // required init?(coder:) is the NSWindowController contract, but the app
    // never constructs this from a coder — trap with fatalError.
    private init() {
        // Wrap the SwiftUI view in an NSViewController.
        let rootView = SettingsView(preferences: .shared)
        let hosting = NSHostingController(rootView: rootView)

        // The window sizes itself to the hosting controller's view.
        // Passing contentViewController builds a titled regular window
        // automatically, which is simpler than calling NSWindow's designated
        // init directly.
        let window = NSWindow(contentViewController: hosting)
        window.title = "Hotaru 設定"
        window.styleMask = [.titled, .closable]

        // Important: do NOT release the window when it closes.
        // By default NSWindow is released on close; we keep it alive so the
        // user can reopen the same window repeatedly.
        window.isReleasedWhenClosed = false

        // Center on first display.
        window.center()

        super.init(window: window)
        // Become the NSWindowDelegate so we can hook close behavior later if needed.
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController does not support coder-based init")
    }

    // MARK: - Public API

    // Entry point used by the menu bar controller.
    // - LSUIElement apps need to activate first so the window actually comes forward.
    // - If the window is already open, activating again brings it to the front.
    func show() {
        NSApp.activate()
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
    }
}
