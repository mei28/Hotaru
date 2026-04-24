import SwiftUI

// @main marks the Swift entry point.
// Decorating a type that conforms to the App protocol makes its `body` evaluated
// at launch. Instead of a free `fn main()`, Swift uses a type-based declaration.
@main
struct HotaruApp: App {
    // @NSApplicationDelegateAdaptor is a property wrapper that constructs an
    // AppDelegate behind the scenes and assigns it to NSApplication.shared.delegate.
    // It is the glue that bridges the SwiftUI world (struct-based) to the AppKit
    // lifecycle (class + delegate callbacks).
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene: a window that is opened from the app menu or our own menu.
        // Declaring it on the SwiftUI side lets AppKit code open it via
        //   NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // (MenuBarController still opens its own NSWindow directly because that
        // selector is unreliable for LSUIElement apps — see SettingsWindowController).
        //
        // Preferences.shared is passed so the whole app shares a single settings
        // instance.
        Settings {
            SettingsView(preferences: Preferences.shared)
        }
    }
}
