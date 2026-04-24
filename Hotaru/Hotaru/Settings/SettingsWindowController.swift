import AppKit
import SwiftUI

// 設定ウィンドウ専用の NSWindowController。
//
// なぜ SwiftUI の `Settings { }` シーン頼みをやめたか:
//   - LSUIElement アプリ(Dock アイコン無し)では main menu が空に近く、
//     `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)` の responder chain
//     に Settings シーンのハンドラが届かないケースがある
//   - その結果、メニューバーから「設定…」を叩いてもウィンドウが出てこない
// → AppKit の世界で NSWindow を自分で作り、SwiftUI ビューを NSHostingController
//   で埋め込む形にする。こちらの方が挙動が決定論的。
//
// NSHostingController<Content: View>:
//   - SwiftUI ビュー階層を AppKit の NSViewController としてラップする橋渡し
//   - 中身の SwiftUI は通常通り @ObservedObject で Preferences を監視するので、
//     Preferences.shared を渡すだけでそれ以降の変更は自動で再描画される
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    // シングルトン: 設定ウィンドウは 1 つだけあれば十分。
    // Swift の static let は初回アクセス時に thread-safe に生成される(Swift 言語保証)。
    static let shared = SettingsWindowController()

    // init(window:) をカスタマイズするため designated init を private で作る。
    // required init?(coder:) は NSWindowController のプロトコル要件だが、
    // コード起動専用なので fatalError にしておく。
    private init() {
        // SwiftUI ビューを NSViewController へラップ
        let rootView = SettingsView(preferences: .shared)
        let hosting = NSHostingController(rootView: rootView)

        // ウィンドウは hosting のビューを自動でサイズに合わせる。
        // contentViewController を渡す形にすると、タイトルバー付きの通常ウィンドウが
        // 自動的に組み上がる(NSWindow の designated init を直接叩くより楽)。
        let window = NSWindow(contentViewController: hosting)
        window.title = "Hotaru 設定"
        window.styleMask = [.titled, .closable]

        // 重要: close したときにウィンドウを release しない。
        // 既定の NSWindow は閉じると解放されるが、再度開けるよう生かしておく。
        window.isReleasedWhenClosed = false

        // 初回表示位置を画面中央に
        window.center()

        super.init(window: window)
        // NSWindowDelegate になっておくと将来クローズ時のフックを挟める(今は未使用)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController does not support coder-based init")
    }

    // MARK: - Public API

    // メニューバーから呼ばれるエントリ。
    // - LSUIElement なのでアプリを前面に出してからウィンドウを key にする
    // - 既に開いていれば再 activate だけで前面に持って来られる
    func show() {
        NSApp.activate()
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
    }
}
