import SwiftUI
import AppKit

// 設定ウィンドウの SwiftUI ビュー。
// App 側の `Settings { SettingsView(...) }` シーンに差し込まれて、アプリメニュー
// (あるいはメニューバーの「設定…」)から開かれる。
//
// SwiftUI の考え方:
//   - @ObservedObject で Preferences(ObservableObject)を監視。値変更で View 再描画。
//   - $preferences.xxx でプロパティに対する Binding<T> を得る(2-way バインディング)。
//   - NSColor は SwiftUI.Color と互換がないので、Binding<Color> を get/set で橋渡しする。
struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Hotaru を有効にする", isOn: $preferences.isEnabled)
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

                // Slider は Double を受ける。CGFloat → Double の変換は Binding で行う。
                HStack {
                    Text("幅")
                    Slider(value: widthBinding, in: 1...10, step: 1)
                    Text("\(Int(preferences.borderWidth))px")
                        .monospacedDigit()  // 数字幅を等幅化し、値変動でズレないように
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
        .formStyle(.grouped)  // macOS System Settings 風のカードスタイル
        .frame(width: 480, height: 520)
    }

    // MARK: - プレビュー

    private var previewRect: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(previewColor, lineWidth: preferences.borderWidth)
    }

    // プレビューは今の外観(ライト/ダーク)に合わせた色で描画する。
    // LSUIElement アプリは NSApp.effectiveAppearance が固定されるため、
    // システムのダークモード判定はグローバル UserDefaults キー AppleInterfaceStyle
    // を読む方式で行う(Dark=ダーク、nil=ライト)。
    private var previewColor: Color {
        let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let ns = isDark ? preferences.borderColorDark : preferences.borderColorLight
        return Color(nsColor: ns)
    }

    // MARK: - Binding ブリッジ

    // ColorPicker は Binding<Color> を要求する。Preferences は NSColor を持つので、
    // get/set 両方向を自前で書く「カスタム Binding」を作って橋渡しする。
    // Rust の From/Into 両方向実装と似た感覚。
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

    // Slider は Binding<Double> を要求。CGFloat との変換もここで吸収。
    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(preferences.borderWidth) },
            set: { preferences.borderWidth = CGFloat($0) }
        )
    }
}
