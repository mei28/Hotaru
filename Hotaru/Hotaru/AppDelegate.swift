import AppKit

// NSApplicationDelegate: AppKit アプリのライフサイクル通知を受け取るプロトコル。
// applicationDidFinishLaunching / applicationWillTerminate などがここに定義されている。
//
// NSObject を継承するのは、Obj-C ランタイム経由で AppKit から呼び出されるため。
// Swift ネイティブ型のままだと selector / KVO / delegate 通知が動かない。
// Rust で FFI 境界に C ABI が要求されるのと同じ発想で、AppKit 境界に Obj-C ABI が要求される。
//
// final をつけているのは継承禁止の宣言。dynamic dispatch が static dispatch になり、
// コンパイラが最適化しやすくなる。意図的に継承させないクラスには基本つけておく。
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MenuBarController を強参照で保持する。
    // NSStatusItem は所有者がいなくなると ARC により即座に解放され、
    // メニューバーからアイコンが消える。ここで生かし続ける責任を持つ。
    // (Rust で Arc<T> を保持しないと drop されるのと同じ感覚)
    private var menuBarController: MenuBarController?

    // FocusTracker も同様に強参照保持。deinit で NotificationCenter.removeObserver が
    // 必要なので、ライフサイクルを制御するために AppDelegate が所有する。
    private var focusTracker: FocusTracker?

    // OverlayController: 透明ウィンドウの指揮係。
    private var overlayController: OverlayController?

    // 現在アクティブなアプリ用の AX 観測器。アプリが切り替わるたびに作り直す。
    // 古い observer は置き換え時に deinit → AXObserver / RunLoop source が自動で片付く。
    private var windowObserver: WindowObserver?

    // アプリ起動が完了したタイミングで呼ばれる。
    // NSApp が既に初期化済みで、UI を組み立てるのに安全な最初のポイント。
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()

        // Phase 2: AX 権限をチェックし、なければ誘導アラートを出す。
        // 権限がある場合は何もしないので毎回呼んで OK。
        AccessibilityChecker.requestAccessIfNeeded()

        // Phase 5: オーバーレイウィンドウを先に生成してから、
        // FocusTracker → OverlayController のコールバック配線を組む。
        let overlay = OverlayController()
        overlayController = overlay

        // Phase 3+4+5+6: アプリ切替でオーバーレイ即時更新 + そのアプリ用 AX 観測器を張り替え。
        // [weak self, weak overlay] で循環参照回避。AppDelegate / OverlayController は
        // どちらも AppDelegate が強参照しているので、closure 側は弱で十分。
        let tracker = FocusTracker()
        tracker.onFocusChanged = { [weak self, weak overlay] app, info in
            overlay?.update(windowInfo: info)
            self?.rebindWindowObserver(for: app)
        }
        focusTracker = tracker

        // クロージャを繋いだ状態で初期状態を発火(起動直後のフロントアプリに枠を付ける)
        tracker.emitInitial()
    }

    // Phase 6: アクティブアプリが変わるたびに新しい WindowObserver に張り替える。
    // 旧 observer は代入により解放され、deinit で notification / run-loop source が外れる。
    private func rebindWindowObserver(for app: NSRunningApplication) {
        // closure が overlayController を弱参照するためのローカル束縛
        let overlay = overlayController
        windowObserver = WindowObserver(
            pid: app.processIdentifier
        ) { [weak overlay] info in
            // move/resize/focus-change の通知が来るたびに呼ばれる
            overlay?.update(windowInfo: info)
        }
    }
}
