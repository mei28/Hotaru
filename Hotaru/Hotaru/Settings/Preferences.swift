import AppKit
import Combine
import ServiceManagement  // SMAppService: registers/unregisters the app as a login item

// Persists settings and publishes changes to SwiftUI, OverlayController, and
// MenuBarController. A thin UserDefaults wrapper that also conforms to
// ObservableObject.
//
// Why a singleton?
//   - There is only one settings object for the whole app.
//   - Skipping dependency injection through AppDelegate keeps wiring trivial.
// Dependency injection would be cleaner in strict codebases; for a personal
// app the `.shared` tradeoff is fine.
//
// @Published is the property wrapper that SwiftUI's @ObservedObject listens
// to. When the value changes, objectWillChange fires and views re-render.
// didSet is Swift's property observer that runs right after @Published's
// change notification. Saving to UserDefaults here keeps the "change the
// value and persist it" logic in one place.
final class Preferences: ObservableObject {

    static let shared = Preferences()

    // MARK: - Published properties (SwiftUI bindings)

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    @Published var borderColorLight: NSColor {
        didSet { save(color: borderColorLight, forKey: Key.borderColorLight) }
    }

    @Published var borderColorDark: NSColor {
        didSet { save(color: borderColorDark, forKey: Key.borderColorDark) }
    }

    @Published var borderWidth: CGFloat {
        didSet { defaults.set(Double(borderWidth), forKey: Key.borderWidth) }
    }

    // Whether Hotaru launches at login.
    // Updates both SMAppService.mainApp and UserDefaults.
    // If registration fails (unsigned build + missing permission etc.) we only
    // log the error. We could avoid writing to defaults to keep UI and actual
    // state in lockstep, but for a personal-use build it is friendlier to
    // remember the user's intent.
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    // MARK: - Defaults

    static let defaultColorLight = NSColor(
        srgbRed: 1.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0
    )
    static let defaultColorDark = NSColor(
        srgbRed: 127.0 / 255.0, green: 1.0, blue: 107.0 / 255.0, alpha: 1.0
    )
    static let defaultBorderWidth: CGFloat = 3
    static let defaultIsEnabled = true
    static let defaultLaunchAtLogin = true

    // MARK: - UserDefaults keys (matches SPEC §6.1)

    private enum Key {
        static let isEnabled        = "hotaru.isEnabled"
        static let borderColorLight = "hotaru.borderColor.light"
        static let borderColorDark  = "hotaru.borderColor.dark"
        static let borderWidth      = "hotaru.borderWidth"
        static let launchAtLogin    = "hotaru.launchAtLogin"
    }

    private let defaults = UserDefaults.standard

    private init() {
        // register(defaults:) registers fallback values that are returned
        // until the user writes an explicit value via set().
        // NSColor is not plist-compatible, so we don't register a default for
        // it here — the loader falls back to a hardcoded default instead.
        defaults.register(defaults: [
            Key.isEnabled:     Self.defaultIsEnabled,
            Key.borderWidth:   Double(Self.defaultBorderWidth),
            Key.launchAtLogin: Self.defaultLaunchAtLogin,
        ])

        // Load initial values.
        // @Published properties cannot refer to self during init, so we read
        // into local values first and assign them in one shot.
        // (didSet still fires during init and writes back to UserDefaults,
        //  but writing the same value is a no-op in practice.)
        self.isEnabled = defaults.bool(forKey: Key.isEnabled)
        self.borderColorLight = Self.loadColor(from: defaults, forKey: Key.borderColorLight)
            ?? Self.defaultColorLight
        self.borderColorDark  = Self.loadColor(from: defaults, forKey: Key.borderColorDark)
            ?? Self.defaultColorDark
        self.borderWidth = CGFloat(defaults.double(forKey: Key.borderWidth))
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)

        // Reconcile UserDefaults with the actual registration state, in case
        // the user enabled launch-at-login previously but later disabled it
        // via System Settings manually.
        syncLaunchAtLoginState()
    }

    // MARK: - Login item

    // Reflect the desired launchAtLogin value into SMAppService.
    // Failures just go to the console — signing / sandbox issues can make
    // register() throw, but for a personal-use build we do not treat those
    // as fatal.
    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Preferences] SMAppService \(launchAtLogin ? "register" : "unregister") failed: \(error)")
        }
    }

    // If UserDefaults and the actual SMAppService status disagree, take
    // UserDefaults as the source of truth and realign the service.
    private func syncLaunchAtLoginState() {
        let current: Bool
        switch SMAppService.mainApp.status {
        case .enabled: current = true
        default:       current = false
        }
        if current != launchAtLogin {
            applyLaunchAtLogin()
        }
    }

    // MARK: - Actions

    func resetToDefaults() {
        isEnabled = Self.defaultIsEnabled
        borderColorLight = Self.defaultColorLight
        borderColorDark  = Self.defaultColorDark
        borderWidth = Self.defaultBorderWidth
        launchAtLogin = Self.defaultLaunchAtLogin
    }

    // MARK: - NSColor persistence

    // NSColor is not a plist-compatible type, so it cannot be stored in
    // UserDefaults as-is.
    //   (A) NSKeyedArchiver -> Data: compact but binary; worried about color
    //       space and type evolution.
    //   (B) Dictionary of sRGB R/G/B/A Doubles: human-readable, easy to debug.
    // SPEC §6.1 recommends (B), so we use that.
    private func save(color: NSColor, forKey key: String) {
        // The NSColor coming out of ColorPicker can be in any color space
        // (Generic RGB, Device RGB, ...). Normalize to sRGB before
        // decomposing so the round-trip is stable.
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return
        }
        let dict: [String: Double] = [
            "r": Double(rgb.redComponent),
            "g": Double(rgb.greenComponent),
            "b": Double(rgb.blueComponent),
            "a": Double(rgb.alphaComponent),
        ]
        defaults.set(dict, forKey: key)
    }

    private static func loadColor(from defaults: UserDefaults, forKey key: String) -> NSColor? {
        guard let dict = defaults.dictionary(forKey: key) as? [String: Double],
              let r = dict["r"], let g = dict["g"], let b = dict["b"] else {
            return nil
        }
        let a = dict["a"] ?? 1.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
