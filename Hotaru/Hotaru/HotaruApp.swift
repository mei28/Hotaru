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

    // App プロトコルは body: some Scene を要求する。
    // メニューバー常駐アプリはウィンドウが要らないので、Settings {} だけを宣言する。
    // WindowGroup を置くと起動時に空ウィンドウが出てしまうので、ここでは置かない。
    // Settings {} は "アプリメニュー > 設定…" から開くウィンドウの定義。
    // Phase 7 で中身を実装するまでは EmptyView のまま。
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
