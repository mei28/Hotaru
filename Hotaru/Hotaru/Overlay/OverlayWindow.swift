import AppKit

// Transparent NSWindow dedicated to rendering the border.
// It acts as an invisible canvas; the OverlayView on top strokes the border
// via CALayer.
//
// All the settings from SPEC §7.5 are consolidated here.
final class OverlayWindow: NSWindow {

    init() {
        // NSWindow designated initializer.
        // - contentRect: initial frame. `.zero` is fine at construction time;
        //                we move the window later via setFrame.
        // - styleMask: .borderless means no title bar, no close/zoom buttons.
        // - backing: .buffered — double-buffered; always the right choice on
        //            modern macOS.
        // - defer: false — allocate the underlying window resources immediately.
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false                // required for transparency
        backgroundColor = .clear        // fully transparent background
        hasShadow = false               // no window shadow (keeps the border crisp)
        ignoresMouseEvents = true       // let clicks and hover pass through

        // Window level: above regular app windows but below menu-bar items.
        // .statusBar is the high level used by menu bar apps, which sits above
        // almost every app window.
        level = .statusBar

        // collectionBehavior: controls Space / Mission Control / fullscreen behavior.
        //
        // Requirements:
        //   - Do not show above fullscreen apps -> drop .fullScreenAuxiliary
        //   - Stay out of Mission Control / Exposé / App Exposé -> .transient
        //   - Follow the active Space automatically -> .moveToActiveSpace
        //
        //   .moveToActiveSpace : moves to the active Space on every orderFront
        //   .transient         : excluded from Exposé, Mission Control, Dock window row
        //   .stationary        : not caught by Mission Control's scale animation
        //                        (.transient already hides us there; kept as a safety net)
        collectionBehavior = [.moveToActiveSpace, .transient, .stationary]

        // The border itself is drawn by OverlayView.
        // Replace the default contentView with our layer-backed view.
        contentView = OverlayView(frame: .zero)
    }

    // Borderless windows cannot become key by default, so keyboard input is not
    // stolen. That is exactly what we want here, but we state it explicitly
    // for future-proofing.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
