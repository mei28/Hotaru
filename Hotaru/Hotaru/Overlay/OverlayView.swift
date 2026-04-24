import AppKit

// ボーダーを描画する NSView。
// CALayer の borderWidth / borderColor / cornerRadius をそのまま使う最小実装。
//
// CALayer は AppKit / UIKit 共通の描画レイヤー層で、NSView / UIView の下に 1 枚敷かれている。
// wantsLayer = true にすると NSView が自前の layer を持ち、各種描画プロパティが使えるようになる。
// (macOS は歴史的に "layer-backed" がデフォルト OFF。iOS は常に ON。)
final class OverlayView: NSView {

    // 外部から色・幅を変更できるようにしておく。
    // didSet は Swift のプロパティオブザーバ。値が代入されるたびに呼ばれる。
    // Rust には無い機能で、ここで UI 更新をトリガーするのが典型パターン。
    // 仕様書 §2.2 のライトモード既定色 #FFB84D(蛍を思わせる温かい黄)。
    // ダークモード切替は Phase 7(Settings + Preferences)で対応する。
    var borderColor: NSColor = NSColor(
        red: 1.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0
    ) {
        didSet { applyStyle() }
    }

    var borderWidth: CGFloat = 3 {
        didSet { applyStyle() }
    }

    var cornerRadius: CGFloat = 12 {
        didSet { applyStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // layer-backed にする(CALayer を自分で持つ)
        wantsLayer = true
        applyStyle()
    }

    // NSView のサブクラスでは init(coder:) も required で要求される(Interface Builder / Storyboard 用)。
    // プログラム起動オンリーで XIB/Storyboard を使わないので実装不要 → fatalError で未使用を示す。
    required init?(coder: NSCoder) {
        fatalError("OverlayView does not support coder-based init")
    }

    private func applyStyle() {
        // NSView が layer を持っていれば、その layer のプロパティを設定する。
        // ?. で Optional chain: layer が nil なら何もしない(= wantsLayer=false の状態)。
        layer?.borderColor = borderColor.cgColor
        layer?.borderWidth = borderWidth
        layer?.cornerRadius = cornerRadius
        // 境界の外にはみ出さないよう masksToBounds を true に。
        // 今回はボーダーしか描画しないので視覚差はほぼないが、安全側で設定。
        layer?.masksToBounds = true
    }
}
