import Foundation

// Swift-side representation of the window info we obtained via AX.
// `position` is expressed in the AX coordinate system (origin at the
// primary screen's top-left, Y increases downward).
// Conversion to the Cocoa coordinate system lives in ScreenGeometry.
//
// We use a struct (value type: copied on assignment, not shared by reference)
// to keep state tracking simple. A class would let callers observe mutations
// through shared references, which is unnecessary here.
// Same spirit as a plain Rust struct (value type).
struct WindowInfo: Equatable {
    let position: CGPoint  // AX coordinate system
    let size: CGSize

    var frame: CGRect {
        CGRect(origin: position, size: size)
    }
}
