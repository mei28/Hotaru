import AppKit
import Combine

// Coordinator that controls the overlay's visibility, style, and position.
// From Phase 7 it also subscribes to Preferences and tracks color, width,
// enable-flag, and dark-mode changes.
final class OverlayController {

    private let window: OverlayWindow
    private let preferences: Preferences

    // Last WindowInfo we received. Used as the source-of-truth for
    // "where should the border be right now?" when the user toggles
    // isEnabled or tweaks colors.
    private var lastInfo: WindowInfo?

    // Combine cancellables bag. When this is released, the subscriptions end
    // automatically. Set<AnyCancellable> is the canonical Combine idiom.
    private var cancellables = Set<AnyCancellable>()


    private var overlayView: OverlayView? {
        window.contentView as? OverlayView
    }

    init(preferences: Preferences) {
        self.preferences = preferences
        self.window = OverlayWindow()
        applyStyle()
        subscribeToChanges()
    }

    // MARK: - Public

    // Called by FocusTracker / WindowObserver.
    // We keep lastInfo up to date even when isEnabled is false, so that the
    // border jumps to the correct position the moment the user re-enables it.
    func update(windowInfo: WindowInfo?) {
        lastInfo = windowInfo
        if preferences.isEnabled {
            reposition(with: windowInfo)
        } else {
            window.orderOut(nil)
        }
    }

    // MARK: - Internal

    private func reposition(with info: WindowInfo?) {
        guard let info = info else {
            window.orderOut(nil)
            return
        }
        let cocoaFrame = ScreenGeometry.convertAXToCocoa(info.frame)
        // Inflate by borderWidth on every side so the stroke wraps the window
        // edge from outside rather than cutting into its content.
        let inset: CGFloat = preferences.borderWidth
        let expanded = cocoaFrame.insetBy(dx: -inset, dy: -inset)
        window.setFrame(expanded, display: true)
        window.orderFront(nil)
    }

    private func applyStyle() {
        guard let view = overlayView else { return }
        view.borderWidth = preferences.borderWidth
        view.borderColor = currentColor
    }

    // Read the system-wide dark-mode state from the global UserDefaults.
    //
    // Why not NSApp.effectiveAppearance?
    //   - LSUIElement apps rarely have a key window, so effectiveAppearance
    //     does not follow the system's Dark setting — it stays pinned to
    //     "NSAppearanceNameAqua"
    //   - Verified on a real machine: toggling Light/Dark did not change
    //     effectiveAppearance at all
    //
    // We read AppleInterfaceStyle from the global defaults domain instead:
    //   - System Dark  -> "Dark"
    //   - System Light -> nil (the key simply does not exist)
    // This has been a stable contract since macOS 10.14.
    private var isDarkModeActive: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    // Pick the border color that matches the current appearance.
    private var currentColor: NSColor {
        isDarkModeActive ? preferences.borderColorDark : preferences.borderColorLight
    }

    // MARK: - Subscriptions

    private func subscribeToChanges() {
        // Receive every preference change in one place.
        // objectWillChange fires right *before* the value changes; hopping
        // through RunLoop.main gives us one tick of delay, so by the time the
        // sink runs the stored property already holds the new value.
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // Dark-mode change detection:
        // System-wide appearance changes are broadcast on
        // DistributedNotificationCenter under AppleInterfaceThemeChangedNotification
        // (macOS 10.14+).
        //
        // Why not KVO on effectiveAppearance?
        //   - NSApp.effectiveAppearance is pinned to Aqua for LSUIElement apps
        //     (no key window), so KVO does fire but the value never changes
        // DistributedNotificationCenter is the raw system event and arrives
        // reliably.
        DistributedNotificationCenter.default
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyStyle()
                self?.reposition(with: self?.lastInfo)
            }
            .store(in: &cancellables)
    }

    // Full refresh after a preference change:
    //   - push color/width into the view
    //   - show or hide depending on isEnabled
    //   - when the width changes the inset changes too, so the frame has to
    //     be recomputed
    private func refresh() {
        applyStyle()
        if preferences.isEnabled {
            reposition(with: lastInfo)
        } else {
            window.orderOut(nil)
        }
    }
}
