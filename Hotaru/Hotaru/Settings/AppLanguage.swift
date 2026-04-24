import Foundation

// User-facing language choice for the UI.
// - .system lets macOS decide (normal behavior; the AppleLanguages key is unset)
// - .english / .japanese pin the app to that localization via AppleLanguages
//
// Identifiable conformance lets SwiftUI's ForEach / Picker use it directly.
// CaseIterable gives us AppLanguage.allCases for the picker rows.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case japanese

    var id: String { rawValue }

    // Locale used by SwiftUI's `.environment(\.locale, ...)` to make Text()
    // look up strings in the right .lproj live.
    // .system returns the current process Locale so SwiftUI keeps following
    // system settings.
    var locale: Locale {
        switch self {
        case .system:   return .current
        case .english:  return Locale(identifier: "en")
        case .japanese: return Locale(identifier: "ja")
        }
    }

    // Label shown in the picker. Native names for language rows is a common
    // convention: an English speaker reads "English", a Japanese speaker
    // reads "日本語" — neither needs a translation layer for their own name.
    var displayName: String {
        switch self {
        case .system:   return String(localized: "System default")
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }
}
