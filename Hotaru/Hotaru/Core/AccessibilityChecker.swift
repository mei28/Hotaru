import AppKit
import ApplicationServices  // Home of the AX* functions (AppKit pulls it in transitively; importing explicitly for clarity)

// Utility for checking the Accessibility permission and nudging the user to
// grant it when missing. Phase 2 only deals with the gate; actual AX API usage
// (window coordinates) starts in Phase 4.
//
// The `enum + static` pattern is the Swift idiom for "pure utility that cannot
// be instantiated". An enum with no cases cannot construct a value, which
// prevents accidental calls like `AccessibilityChecker()` at the type level.
// (Analogous to Java's `final class` + private constructor, or Rust's
// uninhabited enum.)
enum AccessibilityChecker {

    // Read the current trust status without side effects (no prompt).
    // Useful when the UI needs to poll the permission state later in runtime.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    // Request trust. On the first call, macOS shows its standard permission
    // dialog and also registers the app into the "System Settings > Privacy &
    // Security > Accessibility" list (so the user can flip the toggle easily).
    //
    // On subsequent calls the app is already registered and no OS dialog is
    // shown. The return value is the trust state at this very moment — right
    // after prompting it is typically false.
    @discardableResult
    static func requestTrust() -> Bool {
        // kAXTrustedCheckOptionPrompt is a CFStringRef constant on the C side,
        // but Swift imports it as Unmanaged<CFString>.
        // Unmanaged<T> represents "a reference outside ARC's management",
        // which C functions use when ownership of the returned raw pointer is
        // ambiguous.
        //
        // .takeUnretainedValue() extracts the value without incrementing the
        // retain count. For a constant (no owner) this is the correct choice.
        // (If the constant had come from a Create/Copy-style C function we
        // would use .takeRetainedValue() to take ownership of the count.
        // Similar to deciding whether to Box::from_raw a C-returned raw ptr
        // in Rust.)
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()

        // Toll-free bridging from Swift Dictionary to CFDictionary.
        // CFString / CFBoolean values bridge freely to String / Bool.
        let options: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // Open "System Settings > Privacy & Security > Accessibility" directly.
    // x-apple.systempreferences: is the URL scheme macOS provides for deep
    // linking into specific panes.
    static func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // Show a custom explanation alert, then route the user to System Settings
    // on confirm.
    // @MainActor is a compile-time guarantee that this function only runs on
    // the main thread. AppKit UI (NSAlert etc.) must be touched from main, so
    // the compiler rejects calls from other threads.
    @MainActor
    static func requestAccessIfNeeded() {
        guard !isTrusted else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Accessibility permission required")
        alert.informativeText = String(localized: """
            Hotaru needs Accessibility permission to detect the active window.
            Open System Settings, enable Hotaru in the list, then quit and \
            restart Hotaru.
            """)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Open System Settings"))  // -> .alertFirstButtonReturn
        alert.addButton(withTitle: String(localized: "Later"))                 // -> .alertSecondButtonReturn

        // runModal() is a synchronous modal — blocks until the user clicks.
        // The return value is NSApplication.ModalResponse
        // (.alertFirstButtonReturn etc.).
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Calling requestTrust() once registers the app in the Accessibility
            // list (only effective on first run). Then openSystemSettings()
            // takes the user to the settings pane.
            _ = requestTrust()
            openSystemSettings()
        }
    }
}
