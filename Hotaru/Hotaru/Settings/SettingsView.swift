import SwiftUI
import AppKit

// SwiftUI view for the settings window.
// Embedded either in the App's `Settings { SettingsView(...) }` scene (opened
// from the app menu) or inside our own NSWindow via SettingsWindowController.
//
// SwiftUI essentials used here:
//   - @ObservedObject watches an ObservableObject (Preferences); any change
//     triggers a re-render.
//   - $preferences.xxx yields a Binding<T> for two-way binding.
//   - NSColor is not interchangeable with SwiftUI.Color, so we bridge through
//     a custom Binding<Color> that has explicit get/set closures.
struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Hotaru を有効にする", isOn: $preferences.isEnabled)
                Toggle("ログイン時に起動する", isOn: $preferences.launchAtLogin)
            }

            Section("ボーダー") {
                ColorPicker(
                    "色 (ライトモード)",
                    selection: lightColorBinding,
                    supportsOpacity: false
                )
                ColorPicker(
                    "色 (ダークモード)",
                    selection: darkColorBinding,
                    supportsOpacity: false
                )

                // Slider binds to Double; the CGFloat <-> Double conversion
                // happens inside the custom Binding.
                HStack {
                    Text("幅")
                    Slider(value: widthBinding, in: 1...10, step: 1)
                    Text("\(Int(preferences.borderWidth))px")
                        .monospacedDigit()  // equal digit widths so the value does not jitter
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("プレビュー") {
                previewRect
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            }

            Section {
                Button("デフォルトに戻す") {
                    preferences.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)  // card-based style, similar to macOS System Settings
        .frame(width: 480, height: 520)
    }

    // MARK: - Preview

    private var previewRect: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(previewColor, lineWidth: preferences.borderWidth)
    }

    // Draw the preview with the color that matches the current appearance.
    // NSApp.effectiveAppearance is pinned for LSUIElement apps, so we read
    // the global UserDefaults key AppleInterfaceStyle instead
    // (Dark -> dark mode, nil -> light mode).
    private var previewColor: Color {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let ns = isDark ? preferences.borderColorDark : preferences.borderColorLight
        return Color(nsColor: ns)
    }

    // MARK: - Binding bridges

    // ColorPicker wants a Binding<Color>. Preferences holds NSColor, so we
    // hand-roll a two-way Binding that converts in both directions.
    // Similar in spirit to implementing both From and Into in Rust.
    private var lightColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.borderColorLight) },
            set: { preferences.borderColorLight = NSColor($0) }
        )
    }

    private var darkColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: preferences.borderColorDark) },
            set: { preferences.borderColorDark = NSColor($0) }
        )
    }

    // Slider needs a Binding<Double>, so absorb the CGFloat conversion here.
    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(preferences.borderWidth) },
            set: { preferences.borderWidth = CGFloat($0) }
        )
    }
}
