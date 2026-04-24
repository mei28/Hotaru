import SwiftUI

// @main: Swift のエントリポイント指定。
// 「App プロトコルに準拠した型」を @main で飾ると、この型の body が起動時に評価される。
// fn main() の代わりに型ベースで宣言する流儀、と見ればよい。
@main
struct HotaruApp: App {
    // @NSApplicationDelegateAdaptor は property wrapper で、
    // 裏で AppDelegate を生成し NSApplication.shared.delegate にセットしてくれる。
    // SwiftUI の世界(struct ベース)と AppKit のライフサイクル(class + delegate)を橋渡しする糊。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings シーン: アプリメニューや独自メニューから開かれる設定ウィンドウ。
        // SwiftUI 側でこのシーンを宣言しておくと、AppKit 側から
        //   NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // で開けるようになる(Phase 7 で MenuBarController が使う)。
        //
        // Preferences.shared を渡すことで、アプリ全体で同じ設定インスタンスを共有する。
        Settings {
            SettingsView(preferences: Preferences.shared)
        }
    }
}
