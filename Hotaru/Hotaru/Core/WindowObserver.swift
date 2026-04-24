import ApplicationServices

// 指定 pid のアプリに対して AXObserver を張り、以下 3 つの通知を受ける:
//   - kAXFocusedWindowChangedNotification  : 同一アプリ内でフォーカスが別ウィンドウへ
//   - kAXMovedNotification                  : ウィンドウ移動
//   - kAXResizedNotification                : ウィンドウリサイズ
//
// 通知が来るたびに AX 座標を読み直し、onUpdate クロージャに WindowInfo を流す。
// フォーカスウィンドウが変わった場合は、旧ウィンドウから移動/リサイズ通知を外し、
// 新しいウィンドウに張り直す("rebind")。
//
// --- C 関数コールバックまわりの要点(Swift 学習的にここが山場) ---
//
// AXObserverCallback は `@convention(c)` の関数ポインタ型。
// Swift のクロージャは通常、周囲のスコープをキャプチャできる(環境を持てる)が、
// @convention(c) はキャプチャ不可。ゆえに self を直接クロージャに埋め込めない。
//
// そこで AXObserverAddNotification の第 4 引数 (UnsafeMutableRawPointer?) に
// 「自分自身を void* にしたもの」を渡し、コールバック内で元に戻す。
//
//   - 書き込み側: Unmanaged.passUnretained(self).toOpaque() で void* 化
//     passUnretained = 参照カウントを上げない(ARC 管理の外へ借り出す)
//   - 読み出し側: Unmanaged<T>.fromOpaque(ctx).takeUnretainedValue() で self を復元
//
// Rust で C 側に `*mut Self` を渡し、コールバックで `&*ptr` に戻すのと同じ設計。
// self が解放されないことは、呼び出し側が保証する(= AppDelegate が WindowObserver を
// 強参照で保持し続ける)。
final class WindowObserver {

    private let pid: pid_t
    private let appElement: AXUIElement
    private let onUpdate: (WindowInfo?) -> Void

    // 内部状態: AXObserver 本体と、現在 move/resize を監視しているウィンドウ要素
    private var observer: AXObserver?
    private var windowElement: AXUIElement?

    init(pid: pid_t, onUpdate: @escaping (WindowInfo?) -> Void) {
        self.pid = pid
        self.appElement = AXUIElementCreateApplication(pid)
        self.onUpdate = onUpdate
        setup()
    }

    // インスタンス破棄時に observer を解除。
    // これがないと、release 後のメモリに向けて通知が飛んで crash する可能性がある。
    deinit {
        tearDown()
    }

    // MARK: - Lifecycle

    private func setup() {
        // AXObserver を作る。pid ごとに 1 つ必要。
        // 成功時は inout 変数に値が入る("out パラメータ" を Swift で受ける典型)。
        var obs: AXObserver?
        let err = AXObserverCreate(pid, Self.callback, &obs)
        guard err == .success, let observer = obs else {
            // AX 非対応アプリ / 権限不足などで失敗することがある。
            // その場合は observer=nil のまま生きる(以降の操作は noop)。
            return
        }
        self.observer = observer

        // 通知を受け取るには、observer の run-loop source を CFRunLoop に追加する必要がある。
        // CFRunLoopGetCurrent() は呼び出し元スレッドの run-loop。今はメインスレッド想定なので
        // メインの run-loop に繋がり、コールバックもメインで呼ばれる。
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        // アプリレベルで「フォーカスウィンドウ変更」を購読
        addNotification(kAXFocusedWindowChangedNotification, element: appElement)

        // 現在のフォーカスウィンドウに move/resize を張る + 初期状態を流す
        rebindFocusedWindow()
    }

    private func tearDown() {
        guard let observer = observer else { return }

        // 現在ウィンドウから move/resize を外す
        if let window = windowElement {
            AXObserverRemoveNotification(observer, window, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, window, kAXResizedNotification as CFString)
        }

        // アプリから focus-changed を外す
        AXObserverRemoveNotification(
            observer, appElement, kAXFocusedWindowChangedNotification as CFString
        )

        // run-loop source を外す
        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        self.observer = nil
        self.windowElement = nil
    }

    // MARK: - Rebinding

    // フォーカスウィンドウが変わったとき(または初期化時)に、
    // 旧ウィンドウの move/resize 購読を解除し、新ウィンドウに張り直す。
    private func rebindFocusedWindow() {
        guard let observer = observer else { return }

        // 旧ウィンドウから外す
        if let oldWindow = windowElement {
            AXObserverRemoveNotification(observer, oldWindow, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, oldWindow, kAXResizedNotification as CFString)
        }

        // 新ウィンドウを取得して張り替える
        let newWindow = AXWindowQuery.focusedWindowElement(for: appElement)
        self.windowElement = newWindow

        if let newWindow = newWindow {
            addNotification(kAXMovedNotification, element: newWindow)
            addNotification(kAXResizedNotification, element: newWindow)
        }

        // 今のフレームを 1 回流す(ウィンドウが変わった直後の位置合わせ)
        emitCurrent()
    }

    private func emitCurrent() {
        guard let window = windowElement,
              let info = AXWindowQuery.windowInfo(from: window) else {
            onUpdate(nil)
            return
        }
        onUpdate(info)
    }

    // MARK: - Notification plumbing

    private func addNotification(_ name: String, element: AXUIElement) {
        guard let observer = observer else { return }
        // self を void* にして context として渡す(callback から復元するため)
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, element, name as CFString, context)
    }

    // C 側コールバックから呼ばれる本体。CFString の通知名を見て分岐する。
    // AXObserverCallback は main run-loop 経由で呼ばれる = メインスレッド前提。
    // ApplicationServices 定数は Swift 側では String として入ってくるので、
    // 受け取った CFString を `as String` に落として直接比較できる。
    fileprivate func handle(notification name: CFString) {
        switch name as String {
        case kAXFocusedWindowChangedNotification:
            rebindFocusedWindow()
        case kAXMovedNotification, kAXResizedNotification:
            emitCurrent()
        default:
            break
        }
    }

    // AXObserverCallback 型(@convention(c))に合う関数ポインタ。
    // static let に定数として保持しておくことで、関数ポインタ 1 つぶんの寿命を稼ぐ。
    // クロージャがスコープを一切キャプチャしていない(self 等を参照していない)ことが
    // @convention(c) の必須条件。
    private static let callback: AXObserverCallback = { _, _, notification, context in
        guard let context = context else { return }
        // void* → WindowObserver に復元。参照カウントを触らずに借り出す("borrow")。
        let observer = Unmanaged<WindowObserver>.fromOpaque(context).takeUnretainedValue()
        observer.handle(notification: notification)
    }
}
