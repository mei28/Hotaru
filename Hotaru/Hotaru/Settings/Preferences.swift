import AppKit
import Combine

// 設定値の永続化と、SwiftUI / OverlayController / MenuBarController への配信を担当。
// UserDefaults の薄いラッパ + ObservableObject。
//
// なぜシングルトンか:
//   - 設定はアプリ全体でひとつ
//   - AppDelegate 経由で受け渡す配線コストを削る
// 設計として過度に strict にしたければ依存注入もできるが、個人ユースなので shared で割り切る。
//
// @Published は SwiftUI の @ObservedObject が監視するための propertyWrapper。
// 値が変わると objectWillChange を発火し、View が自動で再描画される。
// didSet は Swift のプロパティオブザーバ: @Published の通知 → didSet の順で走る。
// ここで UserDefaults に保存することで、値の変更と永続化が 1 箇所に閉じる。
final class Preferences: ObservableObject {

    static let shared = Preferences()

    // MARK: - Published 値(SwiftUI バインディング可能)

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

    // MARK: - 既定値

    static let defaultColorLight = NSColor(
        srgbRed: 1.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0
    )
    static let defaultColorDark = NSColor(
        srgbRed: 127.0 / 255.0, green: 1.0, blue: 107.0 / 255.0, alpha: 1.0
    )
    static let defaultBorderWidth: CGFloat = 3
    static let defaultIsEnabled = true

    // MARK: - UserDefaults キー(仕様書 §6.1 に準拠)

    private enum Key {
        static let isEnabled        = "hotaru.isEnabled"
        static let borderColorLight = "hotaru.borderColor.light"
        static let borderColorDark  = "hotaru.borderColor.dark"
        static let borderWidth      = "hotaru.borderWidth"
    }

    private let defaults = UserDefaults.standard

    private init() {
        // register(defaults:) は「ユーザー未設定時の既定値」を登録する。
        // set() で明示書き込みされるまで、こちらの値が読み出される。
        // NSColor は plist 互換ではないのでここに載せず、読み出し側で nil フォールバック。
        defaults.register(defaults: [
            Key.isEnabled:   Self.defaultIsEnabled,
            Key.borderWidth: Double(Self.defaultBorderWidth),
        ])

        // 初期値のロード。@Published は init 中に自分を参照できないので、
        // ローカル変数で読み、プロパティにはまとめて代入する。
        // (didSet は init 中でも走るため、読み戻した値で UserDefaults.set が呼ばれるが、
        //  同じ値の書き込みなので副作用は実質なし)
        self.isEnabled = defaults.bool(forKey: Key.isEnabled)
        self.borderColorLight = Self.loadColor(from: defaults, forKey: Key.borderColorLight)
            ?? Self.defaultColorLight
        self.borderColorDark  = Self.loadColor(from: defaults, forKey: Key.borderColorDark)
            ?? Self.defaultColorDark
        self.borderWidth = CGFloat(defaults.double(forKey: Key.borderWidth))
    }

    // MARK: - 操作

    func resetToDefaults() {
        isEnabled = Self.defaultIsEnabled
        borderColorLight = Self.defaultColorLight
        borderColorDark  = Self.defaultColorDark
        borderWidth = Self.defaultBorderWidth
    }

    // MARK: - NSColor の永続化

    // NSColor は plist 互換型ではないため、そのままでは UserDefaults に入らない。
    // 選択肢:
    //   (A) NSKeyedArchiver で Data 化 — バイナリだが色空間や型の将来互換が怖い
    //   (B) sRGB の R/G/B/A を Double 辞書で保存 — 人間可読、デバッグしやすい
    // 仕様書 §6.1 の推奨に従い (B) を採用。
    private func save(color: NSColor, forKey key: String) {
        // ColorPicker が返してくる NSColor は任意の色空間(Generic RGB, Device RGB 等)を
        // 持ちうるので、読み書きで変形しないよう sRGB に正規化してから分解する。
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
