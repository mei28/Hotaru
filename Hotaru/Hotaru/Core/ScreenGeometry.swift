import AppKit

// Utilities for converting between the AX and Cocoa coordinate systems.
//
// AX coordinate system (what the Accessibility API returns):
//   - Origin: top-left of the primary screen
//   - Y axis: increases downward (same as Windows / iOS)
//
// Cocoa coordinate system (what NSWindow.frame uses):
//   - Origin: bottom-left of the primary screen
//   - Y axis: increases upward (standard mathematical convention)
//
// X axes point right in both systems; only the Y axis is flipped. The
// reference is the primary screen's height, even on a multi-display setup
// (secondary displays sit in extended coordinates relative to that origin).
enum ScreenGeometry {

    // Height of the primary screen (the one that owns the menu bar; always
    // NSScreen.screens.first). Normally there is at least one display, but we
    // fall back to 0 just in case the Optional is nil.
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    // Convert an AX-space rectangle to Cocoa space.
    //
    // Formula: cocoaY = primaryHeight - axY - windowHeight
    //
    // The windowHeight subtraction is there because AX's origin points at the
    // window's top-left while NSWindow's origin points at the bottom-left. We
    // shift the top Y down by windowHeight to reach the bottom Y.
    static func convertAXToCocoa(_ axFrame: CGRect) -> CGRect {
        let cocoaY = primaryScreenHeight - axFrame.origin.y - axFrame.size.height
        return CGRect(
            x: axFrame.origin.x,
            y: cocoaY,
            width: axFrame.size.width,
            height: axFrame.size.height
        )
    }
}
