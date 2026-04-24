import AppKit
import Combine

// オーバーレイの表示・非表示・スタイル・配置を指揮するコントローラ。
// Phase 7 から Preferences を購読し、色・幅・有効無効・ダークモードの変更に追従する。
final class OverlayController {

    private let window: OverlayWindow
    private let preferences: Preferences

    // 最後に受け取ったウィンドウ情報。isEnabled のトグルや色変更で
    // 再配置するときに "いまどこに出すべきか" の参照元になる。
    private var lastInfo: WindowInfo?

    // Combine の購読を保持する箱。ここから release されると購読も止まる。
    // Set<AnyCancellable> は Swift Combine の標準イディオム。
    private var cancellables = Set<AnyCancellable>()


    private var overlayView: OverlayView? {
        window.contentView as? OverlayView
    }

    init(preferences: Preferences) {
        self.preferences = preferences
        self.window = OverlayWindow()
        applyStyle()
        subscribeToChanges()
    }

    // MARK: - Public

    // FocusTracker / WindowObserver から呼ばれる。
    // isEnabled=false の間も lastInfo は更新しておく(有効化した瞬間に正しい位置へ出すため)。
    func update(windowInfo: WindowInfo?) {
        lastInfo = windowInfo
        if preferences.isEnabled {
            reposition(with: windowInfo)
        } else {
            window.orderOut(nil)
        }
    }

    // MARK: - Internal

    private func reposition(with info: WindowInfo?) {
        guard let info = info else {
            window.orderOut(nil)
            return
        }
        let cocoaFrame = ScreenGeometry.convertAXToCocoa(info.frame)
        // ボーダーぶん外へ張り出す(ストロークがウィンドウの外周を縁取るように)
        let inset: CGFloat = preferences.borderWidth
        let expanded = cocoaFrame.insetBy(dx: -inset, dy: -inset)
        window.setFrame(expanded, display: true)
        window.orderFront(nil)
    }

    private func applyStyle() {
        guard let view = overlayView else { return }
        view.borderWidth = preferences.borderWidth
        view.borderColor = currentColor
    }

    // システムがダークモードかどうかをグローバル UserDefaults から直接読む。
    //
    // なぜ NSApp.effectiveAppearance を使わないか:
    //   - LSUIElement アプリはキーウィンドウを持たないことが多く、effectiveAppearance が
    //     システムの Dark 設定に追従せず "NSAppearanceNameAqua" に張り付いたままになる
    //   - 実機検証でもライト/ダーク切替で effectiveAppearance が変わらないことを確認済み
    //
    // 代わりに AppleInterfaceStyle キーを読む:
    //   - システムがダーク時  → "Dark"
    //   - システムがライト時  → nil(キー自体が存在しない)
    // この挙動は macOS 10.14 以来の安定仕様。
    private var isDarkModeActive: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    // 現在の外観(ライト/ダーク)に応じて採用色を選ぶ。
    private var currentColor: NSColor {
        isDarkModeActive ? preferences.borderColorDark : preferences.borderColorLight
    }

    // MARK: - Subscriptions

    private func subscribeToChanges() {
        // 設定値の変化を一括で受ける。
        // objectWillChange は "これから変わるよ" の通知なので、
        // receive(on: RunLoop.main) で一呼吸置いてから読むと "変わった後の値" が見える。
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // ダークモード切替の監視:
        // システム全体の外観変更は DistributedNotificationCenter にブロードキャストされる。
        // 通知名は AppleInterfaceThemeChangedNotification(macOS 10.14+)。
        //
        // なぜ KVO on effectiveAppearance ではないか:
        //   - LSUIElement アプリはキーウィンドウが無いため NSApp.effectiveAppearance が
        //     システム設定を反映せず固定(Aqua)になる。KVO は発火するが値が変わらない。
        // DistributedNotificationCenter はシステムイベントの素の通知なので安定して届く。
        DistributedNotificationCenter.default
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyStyle()
                self?.reposition(with: self?.lastInfo)
            }
            .store(in: &cancellables)
    }

    // 設定変更時の全面リフレッシュ:
    //   色・幅をビューに反映
    //   isEnabled に応じて表示・非表示
    //   幅が変われば inset も変わるので frame も組み直す
    private func refresh() {
        applyStyle()
        if preferences.isEnabled {
            reposition(with: lastInfo)
        } else {
            window.orderOut(nil)
        }
    }
}
