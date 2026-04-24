import AppKit
import Combine

// Manages the menu-bar icon and its pulldown menu.
// Phase 7: full menu matching SPEC §3.1 — enable toggle, Settings…, About, Quit.
// The enable-toggle item's title updates in response to Preferences changes.
final class MenuBarController: NSObject {

    private let statusItem: NSStatusItem
    private let preferences: Preferences

    // Reference to items whose title we rewrite dynamically
    // (we rewrite the title rather than toggling a checkmark).
    private var enableMenuItem: NSMenuItem?

    // Combine cancellables bag (same idiom as OverlayController).
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences) {
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        super.init()

        configureStatusItem()
        statusItem.menu = buildMenu()
        subscribeToPreferences()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        // SF Symbols `sparkles`: multi-particle sparkle, evoking a firefly's glow.
        // Setting isTemplate = true makes the menu bar tint the image
        // automatically (black on light, white on dark).
        let image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Hotaru"
        )
        image?.isTemplate = true
        button.image = image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // 1. Enable / disable toggle
        let enable = makeItem(
            title: toggleTitle(for: preferences.isEnabled),
            action: #selector(toggleEnabled(_:)),
            key: ""
        )
        menu.addItem(enable)
        self.enableMenuItem = enable

        menu.addItem(.separator())

        // 2. Settings… (Cmd+,)
        menu.addItem(makeItem(
            title: String(localized: "Settings…"),
            action: #selector(openSettings(_:)),
            key: ","
        ))

        menu.addItem(.separator())

        // 3. About
        menu.addItem(makeItem(
            title: String(localized: "About Hotaru"),
            action: #selector(openAbout(_:)),
            key: ""
        ))

        // 4. Quit
        menu.addItem(makeItem(
            title: String(localized: "Quit Hotaru"),
            action: #selector(quitApp(_:)),
            key: "q"
        ))

        return menu
    }

    // Helper for building NSMenuItem. Always sets target = self.
    private func makeItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func toggleTitle(for isEnabled: Bool) -> String {
        isEnabled
            ? String(localized: "Disable Hotaru")
            : String(localized: "Enable Hotaru")
    }

    // MARK: - Subscriptions

    private func subscribeToPreferences() {
        // Rewrite the toggle-item title whenever isEnabled changes.
        // objectWillChange fires *before* the change, so we defer one tick via
        // RunLoop.main to read the post-change value.
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.enableMenuItem?.title = self.toggleTitle(for: self.preferences.isEnabled)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: Any?) {
        preferences.isEnabled.toggle()
    }

    @objc private func openSettings(_ sender: Any?) {
        // The SwiftUI Settings scene + showSettingsWindow: selector path is
        // unreliable for LSUIElement apps, so we use our own NSWindowController
        // instead.
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout(_ sender: Any?) {
        NSApp.activate()
        // The About panel is a standard AppKit dialog. No specific receiver is
        // needed — NSApp handles it directly.
        NSApp.orderFrontStandardAboutPanel(sender)
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
}
