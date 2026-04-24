import AppKit
import os.log

// Tracks the frontmost (active) application.
// Subscribes to NSWorkspace notifications to detect app switches.
// Phase 3 only logged events; from Phase 4 onward this also queries the AX API
// for the focused window's coordinates.

// os.Logger is a thin wrapper over the Unified Logging System.
// - Filterable by subsystem and category
// - Viewable in Console.app or via `log stream --predicate ...`
// - Use .info for records we want to keep in release, .debug for dev-only
private let log = Logger(subsystem: "com.waddlier.Hotaru", category: "focus")

final class FocusTracker: NSObject {

    // Closure invoked on every focus change.
    // AppDelegate / OverlayController use it to reposition the overlay.
    //
    // @escaping tells the compiler "this closure outlives the call". A
    // non-@escaping closure (local, temporary) can live on the stack cheaply;
    // one that is stored as an instance property must be @escaping.
    //
    // Optional so the class is usable before the closure is assigned.
    var onFocusChanged: ((NSRunningApplication, WindowInfo?) -> Void)?

    override init() {
        super.init()

        // NSWorkspace.shared.notificationCenter is its own notification center,
        // separate from NotificationCenter.default. App-switch notifications
        // are delivered here, so do not confuse the two.
        //
        // addObserver(observer:selector:name:object:) is the classic Obj-C
        // API shape:
        // - observer: self
        // - selector: the @objc method to call
        // - name:     the notification identifier
        // - object:   nil accepts notifications from any source; pass a
        //             specific object to filter.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // The initial state is not fired from init — onFocusChanged is nil at
        // this point. The owner (AppDelegate) calls emitInitial() after wiring
        // up the closure.
    }

    // Fire the initial state once so that the app that is already frontmost
    // at launch receives a border.
    // Kept separate from init because onFocusChanged is not yet set during init.
    func emitInitial() {
        if let app = NSWorkspace.shared.frontmostApplication {
            handleActivation(app, reason: "initial")
        }
    }

    // Unsubscribing is required: if notifications fire after self is deallocated
    // the program crashes.
    // Swift block-based observers (addObserver(forName:object:queue:using:))
    // tear down automatically, but the selector-based API does not.
    // deinit is the class-level teardown hook, equivalent to a Rust `Drop` impl.
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // Receives NSWorkspace.didActivateApplicationNotification.
    // userInfo is [AnyHashable: Any]? so we traverse it via optional chaining
    // and a conditional downcast (`as?`) to reach the NSRunningApplication.
    // `guard let ... else { return }` is the early-exit pattern.
    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
            return
        }
        handleActivation(app, reason: "switch")
    }

    // Hub that combines logging, AX query and callback dispatch so that both
    // the initial and switch paths run the same pipeline.
    private func handleActivation(_ app: NSRunningApplication, reason: String) {
        logActive(app, reason: reason)
        let info = AXWindowQuery.focusedWindowInfo(pid: app.processIdentifier)
        logFocusedWindow(info)
        onFocusChanged?(app, info)
    }

    private func logActive(_ app: NSRunningApplication, reason: String) {
        // ?? is the nil-coalescing operator (Swift's counterpart to Rust's
        // Option::unwrap_or(default)).
        let name = app.localizedName ?? "(unnamed)"
        let bundleID = app.bundleIdentifier ?? "(no bundle id)"
        let pid = app.processIdentifier
        log.debug("\(reason, privacy: .public) app=\(name, privacy: .public) bundle=\(bundleID, privacy: .public) pid=\(pid)")
    }

    // Receives the already-fetched WindowInfo from handleActivation and logs it.
    // Electron apps (Slack, Dia …) have thin AX trees, so nil is common here.
    private func logFocusedWindow(_ info: WindowInfo?) {
        guard let info = info else {
            log.debug("no focused window (AX not granted / app unresponsive / no window)")
            return
        }
        let ax = info.frame
        let cocoa = ScreenGeometry.convertAXToCocoa(ax)
        log.debug("AX    origin=(\(ax.origin.x), \(ax.origin.y)) size=(\(ax.size.width)×\(ax.size.height))")
        log.debug("Cocoa origin=(\(cocoa.origin.x), \(cocoa.origin.y)) size=(\(cocoa.size.width)×\(cocoa.size.height))")
    }
}
