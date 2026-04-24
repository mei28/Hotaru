import AppKit

// フロントアプリ(最前面でアクティブなアプリ)を追跡するクラス。
// NSWorkspace の通知を購読して、切り替わりを検知する。
// Phase 3 時点ではログ出力のみ。Phase 4 以降で、ここから AX API を使って
// アクティブウィンドウの座標を取得する処理に拡張する。
final class FocusTracker: NSObject {

    // フォーカスが変わるたびに呼ばれるコールバック。
    // AppDelegate / OverlayController 側でオーバーレイの位置更新に使う。
    //
    // @escaping は「このクロージャは関数終了後も保持される」ことをコンパイラに伝える属性。
    // 関数ローカルの一時クロージャ(@escaping でない)はスタック格納で安く済むが、
    // インスタンスプロパティに溜めるような用途には @escaping が必要。
    //
    // Optional にしてあるのは、セットされる前でもクラス自体は動けるようにするため。
    var onFocusChanged: ((NSRunningApplication, WindowInfo?) -> Void)?

    override init() {
        super.init()

        // NSWorkspace.shared.notificationCenter は NSWorkspace 固有の通知センター。
        // 通常の NotificationCenter.default とは別系統。
        // アプリ切替え通知はこちらに流れるので、間違えないこと。
        //
        // addObserver(observer:selector:name:object:) は Obj-C 由来の古典的な API。
        // - observer: 自分(self)
        // - selector: 呼ばれるメソッド(@objc 必須)
        // - name:     通知名
        // - object:   nil にすれば全ソースから受ける。特定のオブジェクトだけに絞りたい時は指定
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // 初期状態は init 時点では発火しない(クロージャがまだセットされていないため)。
        // 購読側(AppDelegate)が onFocusChanged を設定した後に emitInitial() を呼ぶ。
    }

    // 起動時のフロントアプリを 1 回だけ通知する。
    // init と分離してあるのは、init 内では onFocusChanged がまだ nil のため。
    func emitInitial() {
        if let app = NSWorkspace.shared.frontmostApplication {
            handleActivation(app, reason: "initial")
        }
    }

    // observer を外さないと、解放後の self へ通知が飛んで crash する可能性がある。
    // Swift の block-based observer(addObserver(forName:object:queue:using:))
    // なら自動解除されるが、今回の selector ベースは明示解除が必要。
    // deinit は Rust の `Drop` impl 相当のクラス解放時フック。
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // NSWorkspace.didActivateApplicationNotification の受け口。
    // userInfo は [AnyHashable: Any]? なので、目的の型 NSRunningApplication まで
    // Optional chain + ダウンキャスト(as?)で辿る必要がある。
    // guard let ... else { return } で「取れなかったら何もしない」パターン。
    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
            return
        }
        handleActivation(app, reason: "switch")
    }

    // ログ出力と AX 問い合わせ、コールバック呼び出しを一箇所にまとめる。
    // init / switch の両経路から同じ処理を走らせるためのハブ。
    private func handleActivation(_ app: NSRunningApplication, reason: String) {
        logActive(app, reason: reason)
        let info = AXWindowQuery.focusedWindowInfo(pid: app.processIdentifier)
        logFocusedWindow(info)
        onFocusChanged?(app, info)
    }

    private func logActive(_ app: NSRunningApplication, reason: String) {
        // Optional に対する ?? は nil 合体演算子。
        // Rust の Option::unwrap_or(default) と同じ。
        let name = app.localizedName ?? "(unnamed)"
        let bundleID = app.bundleIdentifier ?? "(no bundle id)"
        let pid = app.processIdentifier
        print("[FocusTracker \(reason)] \(name) — \(bundleID) — pid=\(pid)")
    }

    // handleActivation で既に取得済みの WindowInfo を受け取ってログ化するだけに変えた。
    // Electron 系アプリ(Slack / Dia など)は AX ツリーが貧弱で nil が返ることがある。
    private func logFocusedWindow(_ info: WindowInfo?) {
        guard let info = info else {
            print("  └ no focused window (AX 未許可 / 対象アプリが応答なし / ウィンドウ無し)")
            return
        }
        let axFrame = info.frame
        let cocoaFrame = ScreenGeometry.convertAXToCocoa(axFrame)
        print(String(format: "  └ AX    origin=(%.0f, %.0f)  size=(%.0f × %.0f)",
                     axFrame.origin.x, axFrame.origin.y, axFrame.size.width, axFrame.size.height))
        print(String(format: "  └ Cocoa origin=(%.0f, %.0f)  size=(%.0f × %.0f)",
                     cocoaFrame.origin.x, cocoaFrame.origin.y, cocoaFrame.size.width, cocoaFrame.size.height))
    }
}
