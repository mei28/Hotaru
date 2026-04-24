import AppKit

// NSView that draws the border.
// Minimal implementation that leans on CALayer's borderWidth / borderColor /
// cornerRadius properties.
//
// CALayer is the shared rendering layer used by both AppKit and UIKit — every
// NSView / UIView has one underneath. Setting wantsLayer = true gives the
// NSView its own layer and unlocks these drawing properties.
// (On macOS, "layer-backed" is historically opt-in; on iOS it is always on.)
final class OverlayView: NSView {

    // Color and width can be changed externally.
    // didSet is Swift's property observer, invoked after each assignment.
    // Rust has no direct equivalent; the typical use here is to trigger a UI
    // refresh whenever the value changes.
    //
    // Default color #FFB84D (SPEC §2.2 light-mode default — a warm firefly-ish yellow).
    // Dark-mode switching lands in Phase 7 (Settings + Preferences).
    var borderColor: NSColor = NSColor(
        red: 1.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0
    ) {
        didSet { applyStyle() }
    }

    var borderWidth: CGFloat = 3 {
        didSet { applyStyle() }
    }

    var cornerRadius: CGFloat = 12 {
        didSet { applyStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Make the view layer-backed (it gets its own CALayer).
        wantsLayer = true
        applyStyle()
    }

    // Subclasses of NSView must also implement init?(coder:) (required for
    // Interface Builder / Storyboard). We construct everything in code, so
    // this initializer is never used — trap with fatalError to signal that.
    required init?(coder: NSCoder) {
        fatalError("OverlayView does not support coder-based init")
    }

    private func applyStyle() {
        // Set properties on the layer when it exists.
        // `?.` is optional chaining — does nothing if the layer is nil (that
        // would mean wantsLayer=false, which we never do).
        layer?.borderColor = borderColor.cgColor
        layer?.borderWidth = borderWidth
        layer?.cornerRadius = cornerRadius
        // Clip content to the bounds. We only draw the border here, so the
        // visual difference is negligible — set it for safety.
        layer?.masksToBounds = true
    }
}
