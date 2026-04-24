import AppKit

// オーバーレイの表示・非表示・配置を指揮するコントローラ。
// Phase 5: アプリ切替時(FocusTracker の通知経由)に、アクティブウィンドウの周囲へ
// ボーダーを移動する。移動・リサイズの追従は Phase 6 で AXObserver を組んだ後。
final class OverlayController {

    private let window: OverlayWindow
    private var overlayView: OverlayView? {
        // contentView は NSView? なので as? で OverlayView にダウンキャスト。
        // OverlayWindow が必ず OverlayView を contentView に持つ前提だが、
        // 型的には NSView としてしか受け取れないので変換が要る。
        window.contentView as? OverlayView
    }

    // ボーダーがウィンドウの外周をちょうど縁取るよう、ウィンドウ枠ぶん外へ張り出す量。
    // 値が大きいほどボーダーが太く見える(= OverlayView の borderWidth と同じ値にしておく)。
    private var borderWidth: CGFloat {
        overlayView?.borderWidth ?? 3
    }

    init() {
        window = OverlayWindow()
    }

    // FocusTracker から渡される WindowInfo(AX 座標系)を受けて、
    // Cocoa 座標系に変換し、ウィンドウ枠の外側を borderWidth ぶん張り出した位置に配置する。
    // nil(ウィンドウ無し・AX 取得失敗)ならオーバーレイを隠す。
    func update(windowInfo: WindowInfo?) {
        guard let info = windowInfo else {
            hide()
            return
        }

        // AX (左上原点) → Cocoa (左下原点) に変換
        let cocoaFrame = ScreenGeometry.convertAXToCocoa(info.frame)

        // ウィンドウの外側を縁取るため、上下左右に borderWidth だけ拡張する。
        // insetBy(dx: -w, dy: -w) は「外側に w 広げる」。
        let inset: CGFloat = borderWidth
        let expandedFrame = cocoaFrame.insetBy(dx: -inset, dy: -inset)

        // NSWindow.setFrame(_:display:) は指定矩形にウィンドウを再配置して再描画する。
        // animate: false 相当(アニメーション付きの別メソッドはあるが、今は瞬時に移動)。
        window.setFrame(expandedFrame, display: true)

        // orderFront: 前面に持ってくる(表示状態にする)。
        // 引数 sender は "誰が呼んだか" の情報で、nil で問題ない。
        window.orderFront(nil)
    }

    func hide() {
        // orderOut: ウィンドウを画面外へ(実際は非表示状態へ)移動する。
        // orderOut(nil) で非表示化、リソースは解放されないので次回 orderFront ですぐ復帰。
        window.orderOut(nil)
    }
}
