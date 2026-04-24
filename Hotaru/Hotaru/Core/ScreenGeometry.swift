import AppKit

// AX 座標系 ⇄ Cocoa 座標系 の変換ユーティリティ。
//
// AX 座標系 (Accessibility API が返す):
//   - 原点: プライマリスクリーンの左上
//   - Y 軸: 下向きに増加(Windows / iOS と同じ)
//
// Cocoa 座標系 (NSWindow.frame などで使う):
//   - 原点: プライマリスクリーンの左下
//   - Y 軸: 上向きに増加(数学的な直交座標)
//
// 両系とも X 軸は右向きで同じ。Y 軸だけが反転している。
// 基準は "プライマリスクリーン" の高さ。マルチディスプレイでも
// この基準で統一されている(セカンダリは拡張座標で扱う)。
enum ScreenGeometry {

    // プライマリスクリーン(メニューバーがある画面、常に NSScreen.screens.first)の高さ。
    // ディスプレイがまったく無い状況は通常ありえないが、Optional に備えて 0 にフォールバック。
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    // AX 座標の矩形を Cocoa 座標に変換する。
    //
    // 変換式:   cocoaY = primaryHeight - axY - windowHeight
    //
    // - windowHeight を引くのは、AX の原点がウィンドウの "左上"、
    //   Cocoa の NSWindow 原点がウィンドウの "左下" を指すため。
    //   ウィンドウの上端 Y を下端 Y に平行移動する分だけ引いている。
    static func convertAXToCocoa(_ axFrame: CGRect) -> CGRect {
        let cocoaY = primaryScreenHeight - axFrame.origin.y - axFrame.size.height
        return CGRect(
            x: axFrame.origin.x,
            y: cocoaY,
            width: axFrame.size.width,
            height: axFrame.size.height
        )
    }
}
