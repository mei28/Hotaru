import ApplicationServices
import CoreGraphics

// Uses the Accessibility API to retrieve the focused window's position and
// size for a given pid. The heart of Phase 4; Phase 6 extends it with
// AXObserver notifications (move/resize subscription).
//
// The AX API lives below the Objective-C runtime, at the Core Foundation C
// layer. In Swift this leaks through as:
//   - CF types (CFTypeRef / AXValue / AXUIElement) appear directly
//   - out parameters demand UnsafeMutablePointer<...> (Swift accepts `&var` via inout)
//   - errors surface as the AXError enum
// In other words, it retains a "C-ish" flavor — similar to touching a C struct
// through an FFI boundary in Rust.
enum AXWindowQuery {

    // Return the focused-window info (in AX coordinates) for the active app.
    // Returns nil in any of the following cases:
    //   - AX permission is not granted
    //   - The app is unresponsive or has no window
    //   - Apps with a thin AX tree (Electron) that do not expose a focused window
    static func focusedWindowInfo(pid: pid_t) -> WindowInfo? {
        // Build the app's root AX element from the pid. Returns an AXUIElement (CF type).
        let appElement = AXUIElementCreateApplication(pid)
        guard let windowElement = focusedWindowElement(for: appElement) else {
            return nil
        }
        return windowInfo(from: windowElement)
    }

    // Fetch the focused window's AXUIElement from an app element.
    // The Phase 6 WindowObserver uses this to re-fetch the element after
    // receiving a kAXFocusedWindowChangedNotification at the app level.
    static func focusedWindowElement(for appElement: AXUIElement) -> AXUIElement? {
        copyElement(from: appElement, attribute: kAXFocusedWindowAttribute)
    }

    // Read the current position and size from a window element and return a
    // WindowInfo. Used to re-read the frame after a move/resize notification.
    static func windowInfo(from windowElement: AXUIElement) -> WindowInfo? {
        var position = CGPoint.zero
        var size = CGSize.zero
        guard copyAXValueInto(
                &position,
                from: windowElement,
                attribute: kAXPositionAttribute,
                valueType: .cgPoint
              ),
              copyAXValueInto(
                &size,
                from: windowElement,
                attribute: kAXSizeAttribute,
                valueType: .cgSize
              )
        else {
            return nil
        }
        return WindowInfo(position: position, size: size)
    }

    // MARK: - Low-level AX wrappers

    // Wrapper for attributes that return an AXUIElement (a reference type such
    // as a window or a button).
    //
    // AXUIElementCopyAttributeValue is a C function whose out parameter is an
    // UnsafeMutablePointer<CFTypeRef?>. Swift lets us declare a CFTypeRef?
    // variable and pass `&value`; the `&` sugar produces the inout pointer
    // that the C function expects.
    private static func copyElement(from element: AXUIElement, attribute: String) -> AXUIElement? {
        var rawValue: CFTypeRef?  // CFTypeRef = AnyObject, the common root of all CF types
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)

        // err is AXError (an enum). Anything other than .success is a failure.
        // Common errors:
        //   .apiDisabled           : AX is disabled at the OS level
        //   .cannotComplete        : permission missing, or target process unresponsive
        //   .attributeUnsupported  : this element does not have that attribute
        //   .noValue               : the attribute exists but has no value
        guard err == .success, let value = rawValue else { return nil }

        // The attribute name fixes the concrete type, so a force cast to
        // AXUIElement is safe. `as!` crashes on mismatch — only use it when
        // the type is guaranteed.
        return (value as! AXUIElement)
    }

    // Wrapper for attributes wrapped in AXValue (CGPoint / CGSize / CGRect /
    // CFRange, ...).
    //
    // Generic + inout combo:
    //   - T is the destination type chosen by the caller
    //   - AXValueGetValue is a C function wanting a pointer to write into
    //   - `&result` turns the inout parameter into that pointer
    //
    // The function returns Bool for success/failure and writes the value
    // through the inout parameter. The Rust equivalent would be
    // `fn f(out: &mut T) -> bool`.
    private static func copyAXValueInto<T>(
        _ result: inout T,
        from element: AXUIElement,
        attribute: String,
        valueType: AXValueType
    ) -> Bool {
        var rawValue: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard err == .success, let value = rawValue else { return false }

        // The payload is an AXValue (an opaque container for CGPoint/CGSize etc.).
        // AXValueGetValue writes the contents into the buffer we pass, matching
        // `valueType`. A mismatched (valueType, T) pair just yields false.
        //
        // Passing `&result` directly would implicitly convert to
        // UnsafeMutableRawPointer, but the compiler warns when T might be a
        // reference type. Using withUnsafeMutablePointer explicitly produces a
        // typed pointer, which we then lower to a raw pointer deliberately.
        let axValue = value as! AXValue
        return withUnsafeMutablePointer(to: &result) { ptr in
            AXValueGetValue(axValue, valueType, UnsafeMutableRawPointer(ptr))
        }
    }
}
