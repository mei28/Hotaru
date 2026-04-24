import ApplicationServices

// Attaches an AXObserver to the given pid and receives three notifications:
//   - kAXFocusedWindowChangedNotification : focus moves to a different window in the same app
//   - kAXMovedNotification                : window moved
//   - kAXResizedNotification              : window resized
//
// For every notification we re-read AX coordinates and push a fresh WindowInfo
// through the onUpdate closure. When the focused window itself changes we
// detach move/resize from the old window and re-attach them on the new one
// (the "rebind" step).
//
// --- Key points about the C-style callback (where Swift gets tricky) ---
//
// AXObserverCallback is a `@convention(c)` function-pointer type.
// Swift closures normally capture their surrounding scope (they carry an
// environment), but @convention(c) forbids captures. So we cannot embed `self`
// directly in the callback.
//
// The workaround is to pass self through the fourth argument of
// AXObserverAddNotification (UnsafeMutableRawPointer?) — our own `self`
// erased to void* — and recover it inside the callback.
//
//   - Sending side: Unmanaged.passUnretained(self).toOpaque() produces the void*
//     passUnretained keeps the retain count untouched (we only borrow out of ARC).
//   - Receiving side: Unmanaged<T>.fromOpaque(ctx).takeUnretainedValue() restores `self`.
//
// Same design as handing a `*mut Self` to C in Rust and converting it back
// with `&*ptr` inside the callback. The caller is responsible for keeping
// `self` alive: AppDelegate holds WindowObserver in a strong stored property.
final class WindowObserver {

    private let pid: pid_t
    private let appElement: AXUIElement
    private let onUpdate: (WindowInfo?) -> Void

    // Internal state: the AXObserver itself, and the window element currently
    // being watched for move/resize events.
    private var observer: AXObserver?
    private var windowElement: AXUIElement?

    init(pid: pid_t, onUpdate: @escaping (WindowInfo?) -> Void) {
        self.pid = pid
        self.appElement = AXUIElementCreateApplication(pid)
        self.onUpdate = onUpdate
        setup()
    }

    // Tear down the observer when we go away. Otherwise callbacks may fire
    // against freed memory and crash the process.
    deinit {
        tearDown()
    }

    // MARK: - Lifecycle

    private func setup() {
        // Create an AXObserver. One per pid.
        // On success the value is written to the inout variable — the classic
        // Swift shape for accepting a C "out parameter".
        var obs: AXObserver?
        let err = AXObserverCreate(pid, Self.callback, &obs)
        guard err == .success, let observer = obs else {
            // Common failure reasons: app does not expose AX, permission is
            // missing, etc. In that case we stay alive with observer=nil;
            // every subsequent operation is a noop.
            return
        }
        self.observer = observer

        // To actually receive notifications we must register the observer's
        // run-loop source on a CFRunLoop.
        // CFRunLoopGetCurrent() returns the caller's run loop. We assume the
        // caller is on the main thread, so callbacks arrive on the main thread.
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        // Subscribe at the app level for "focused window changed".
        addNotification(kAXFocusedWindowChangedNotification, element: appElement)

        // Attach move/resize to the current focused window and emit its initial state.
        rebindFocusedWindow()
    }

    private func tearDown() {
        guard let observer = observer else { return }

        // Detach move/resize from the current window.
        if let window = windowElement {
            AXObserverRemoveNotification(observer, window, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, window, kAXResizedNotification as CFString)
        }

        // Detach focus-changed from the app.
        AXObserverRemoveNotification(
            observer, appElement, kAXFocusedWindowChangedNotification as CFString
        )

        // Remove the run-loop source.
        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        self.observer = nil
        self.windowElement = nil
    }

    // MARK: - Rebinding

    // Called when the focused window changes (and during initial setup).
    // Detaches move/resize from the previous window and attaches them to the
    // new one.
    private func rebindFocusedWindow() {
        guard let observer = observer else { return }

        // Detach from the previous window.
        if let oldWindow = windowElement {
            AXObserverRemoveNotification(observer, oldWindow, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, oldWindow, kAXResizedNotification as CFString)
        }

        // Fetch the new focused window and attach notifications to it.
        let newWindow = AXWindowQuery.focusedWindowElement(for: appElement)
        self.windowElement = newWindow

        if let newWindow = newWindow {
            addNotification(kAXMovedNotification, element: newWindow)
            addNotification(kAXResizedNotification, element: newWindow)
        }

        // Emit the current frame once so the overlay lines up immediately.
        emitCurrent()
    }

    private func emitCurrent() {
        guard let window = windowElement,
              let info = AXWindowQuery.windowInfo(from: window) else {
            onUpdate(nil)
            return
        }
        onUpdate(info)
    }

    // MARK: - Notification plumbing

    private func addNotification(_ name: String, element: AXUIElement) {
        guard let observer = observer else { return }
        // Encode self as a void* context that the callback can restore.
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, element, name as CFString, context)
    }

    // Called from the C callback. Switches on the CFString notification name.
    // AXObserverCallback is dispatched through the main run loop, so this runs
    // on the main thread.
    // ApplicationServices string constants are bridged to Swift as String, so
    // `as String` lets us compare the incoming CFString directly.
    fileprivate func handle(notification name: CFString) {
        switch name as String {
        case kAXFocusedWindowChangedNotification:
            rebindFocusedWindow()
        case kAXMovedNotification, kAXResizedNotification:
            emitCurrent()
        default:
            break
        }
    }

    // Function-pointer value conforming to AXObserverCallback (@convention(c)).
    // Storing it as a `static let` gives it a stable lifetime (one function
    // pointer for the lifetime of the program). Capturing nothing from the
    // surrounding scope is a hard requirement of @convention(c).
    private static let callback: AXObserverCallback = { _, _, notification, context in
        guard let context = context else { return }
        // Restore WindowObserver from the void*. Borrow without touching the
        // retain count.
        let observer = Unmanaged<WindowObserver>.fromOpaque(context).takeUnretainedValue()
        observer.handle(notification: notification)
    }
}
