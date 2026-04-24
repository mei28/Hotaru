import AppKit

// ボーダー表示専用の透明 NSWindow。
// 通常の NSWindow を「見えない土台」として使い、その上の OverlayView が
// CALayer のボーダーで外周を描画する。
//
// 仕様書 §7.5 の設定をすべてここに集約する。
final class OverlayWindow: NSWindow {

    init() {
        // NSWindow の designated init。
        // - contentRect: 最初のフレーム。起動直後は .zero でよい(後で setFrame で更新)
        // - styleMask: .borderless = タイトルバー・枠・閉じるボタン等すべて無し
        // - backing: .buffered = ダブルバッファ、モダン macOS では常にこれで OK
        // - defer: false = すぐに裏側のウィンドウリソースを確保する
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false                // 背景を透過させる前提の設定
        backgroundColor = .clear        // 背景色を完全透明に
        hasShadow = false               // ウィンドウ影を消す(ボーダーが淡くならないように)
        ignoresMouseEvents = true       // クリック・ホバーを下のウィンドウへ素通りさせる

        // ウィンドウレベル: 通常ウィンドウの上、でもメニューバーよりは下。
        // .statusBar はメニューバー用の高レベルで、ほとんどのアプリのウィンドウより前に出る。
        level = .statusBar

        // collectionBehavior: Space / Mission Control / フルスクリーンでの挙動を調整。
        //
        // 要件:
        //   - フルスクリーンアプリでは表示したくない → .fullScreenAuxiliary を外す
        //   - Mission Control / Exposé / App Exposé では残って欲しくない → .transient
        //   - 他 Space に切り替えたときは自動で追従してほしい → .moveToActiveSpace
        //
        //   .moveToActiveSpace : orderFront のたびにアクティブ Space に移る
        //   .transient         : Exposé / Mission Control / Dock 上のウィンドウサムネ列から消える
        //   .stationary        : Mission Control でスケールアニメに巻き込まれない
        //                        (.transient で非表示になるが念のため付けておく)
        collectionBehavior = [.moveToActiveSpace, .transient, .stationary]

        // 実際にボーダーを描くのは OverlayView 側。
        // NSWindow の contentView に差し替える。
        contentView = OverlayView(frame: .zero)
    }

    // borderless ウィンドウは既定で key window になれず、キーボード入力を奪わない。
    // このアプリでは常にそれで問題ないが、念のため明示しておく。
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
