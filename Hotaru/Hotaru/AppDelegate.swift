import AppKit

// NSApplicationDelegate is the AppKit protocol for receiving app lifecycle
// callbacks: applicationDidFinishLaunching / applicationWillTerminate and so on.
//
// We inherit NSObject because AppKit invokes methods through the Objective-C
// runtime (selector, KVO, delegate notifications). A pure Swift type cannot
// be called that way. The same mental model as Rust's FFI boundary requiring
// C ABI — the AppKit boundary requires Obj-C ABI.
//
// `final` forbids subclassing. Dynamic dispatch collapses to static dispatch,
// which helps the compiler optimize. A good default for classes that are
// not intended to be subclassed.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Hold MenuBarController with a strong reference. NSStatusItem is released
    // by ARC as soon as nobody owns it, which makes the icon disappear from
    // the menu bar. We take responsibility for keeping it alive.
    // (Analogous to keeping an Arc<T> alive in Rust so the value is not dropped.)
    private var menuBarController: MenuBarController?

    // FocusTracker also needs a strong reference: its deinit calls
    // NotificationCenter.removeObserver, so its lifetime must be controlled
    // deterministically. AppDelegate owns it.
    private var focusTracker: FocusTracker?

    // OverlayController: coordinator for the transparent overlay window.
    private var overlayController: OverlayController?

    // AX observer for the currently active app. Re-created on every app switch.
    // Replacing this property releases the previous observer, whose deinit
    // tears down the AXObserver and run-loop source.
    private var windowObserver: WindowObserver?

    // Called when application launch is complete. NSApp is already initialized,
    // which makes this the earliest safe place to build UI.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences.shared

        menuBarController = MenuBarController(preferences: preferences)

        // Phase 2: check AX permission and nudge the user if it is missing.
        // Harmless to call on every launch — does nothing when already granted.
        AccessibilityChecker.requestAccessIfNeeded()

        // Phase 5+7: construct the overlay wired to preferences. Color, width,
        // enabled flag and dark-mode tracking are all handled inside
        // OverlayController.
        let overlay = OverlayController(preferences: preferences)
        overlayController = overlay

        // Phases 3+4+5+6: wire FocusTracker -> immediate overlay update, then
        // swap in a fresh WindowObserver for the newly active app.
        // [weak self, weak overlay] avoids reference cycles. Both AppDelegate
        // and OverlayController live on the AppDelegate, so the closure can hold
        // weak references safely.
        let tracker = FocusTracker()
        tracker.onFocusChanged = { [weak self, weak overlay] app, info in
            overlay?.update(windowInfo: info)
            self?.rebindWindowObserver(for: app)
        }
        focusTracker = tracker

        // Fire the initial state now that the closure is wired (so the border
        // appears around whichever app is frontmost at launch).
        tracker.emitInitial()
    }

    // Phase 6: whenever the active app changes, replace the WindowObserver.
    // Assigning to `windowObserver` releases the previous one; its deinit
    // detaches notifications and removes the run-loop source.
    private func rebindWindowObserver(for app: NSRunningApplication) {
        // Local binding so the closure below can hold a weak reference.
        let overlay = overlayController
        windowObserver = WindowObserver(
            pid: app.processIdentifier
        ) { [weak overlay] info in
            // Fires for every move / resize / focus-change notification.
            overlay?.update(windowInfo: info)
        }
    }
}
