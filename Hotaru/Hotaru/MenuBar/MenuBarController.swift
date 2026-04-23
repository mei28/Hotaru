import AppKit

// メニューバーアイコンとプルダウンメニューを管理するクラス。
// Phase 1 時点では "Hotaru を終了" メニュー 1 つの最小構成。
// 以降のフェーズで有効化トグル・設定・About などを追加していく。
final class MenuBarController: NSObject {

    // NSStatusItem: メニューバー右側の 1 マス分の "枠"。
    // NSStatusBar.system.statusItem(...) で払い出してもらい、強参照で保持する。
    // (保持しないと ARC で消える → メニューバーからアイコンが消える)
    private let statusItem: NSStatusItem

    override init() {
        // variableLength はコンテンツ(アイコンやテキスト)の幅に合わせて自動伸縮する指定。
        // 固定幅にする場合は数値を渡すが、アイコンのみの場合は variableLength が標準。
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        // NSObject の init を呼ぶ Swift の規則。
        // 親クラスの初期化を必ず最初に済ませないと、以降で self を参照できない。
        super.init()

        configureStatusItem()
        statusItem.menu = buildMenu()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        // statusItem.button は理論上 Optional(macOS 10.12 以降では常に存在するが
        // 型としては NSStatusBarButton?)。guard let で早期脱出するのが Swift の定番。
        // Rust 1.65+ の `let ... else` と同じ構文感覚。
        guard let button = statusItem.button else { return }

        // SF Symbols からアイコンを生成。
        // accessibilityDescription は VoiceOver 用の代替テキスト。
        // "sparkle" は仮アイコン(仕様書の候補)。後で蛍らしい SF Symbol に差し替え可。
        button.image = NSImage(
            systemSymbolName: "sparkle",
            accessibilityDescription: "Hotaru"
        )
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // NSMenuItem(title:action:keyEquivalent:) の標準コンストラクタ。
        // action に渡す #selector(メソッド名) は "そのメソッドを指す識別子" で、
        // AppKit が Obj-C ランタイム経由で呼び出す。メソッド側に @objc が必要。
        let quit = NSMenuItem(
            title: "Hotaru を終了",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"  // Cmd+Q で呼べる
        )
        // target を明示しないと responder chain を辿って解決される。
        // 自分のメソッドを直接呼びたいので self に固定しておく。
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    // @objc は Obj-C ランタイムに公開する属性。
    // 上の #selector(quitApp(_:)) で参照するために必須。
    // Swift ネイティブのメソッドのままだと、AppKit から動的に呼び出せない。
    //
    // 引数 sender は「誰がこの action を発火したか」を渡す AppKit の慣習。
    // Any? にしておけば、将来メニュー項目以外(ボタン等)からも同じハンドラを使える。
    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
}
