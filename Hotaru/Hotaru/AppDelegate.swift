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

    // アプリ起動が完了したタイミングで呼ばれる。
    // NSApp が既に初期化済みで、UI を組み立てるのに安全な最初のポイント。
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()

        // Phase 2: AX 権限をチェックし、なければ誘導アラートを出す。
        // 権限がある場合は何もしないので毎回呼んで OK。
        AccessibilityChecker.requestAccessIfNeeded()
    }
}
