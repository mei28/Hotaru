import AppKit
import Combine

// メニューバーアイコンとプルダウンメニューを管理するクラス。
// Phase 7: 設定項目の "Hotaru 有効" "設定…" "About" "終了" を揃え、
// Preferences の変化に応じて有効トグル項目の見出しを更新する。
final class MenuBarController: NSObject {

    private let statusItem: NSStatusItem
    private let preferences: Preferences

    // 動的に文面を書き換える項目への参照(checkmark を使う代わりに title 切替方式を採用)
    private var enableMenuItem: NSMenuItem?

    // Combine の購読トークン置き場(OverlayController と同じイディオム)
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences) {
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        super.init()

        configureStatusItem()
        statusItem.menu = buildMenu()
        subscribeToPreferences()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "sparkle",
            accessibilityDescription: "Hotaru"
        )
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // 1. 有効/無効トグル
        let enable = makeItem(
            title: toggleTitle(for: preferences.isEnabled),
            action: #selector(toggleEnabled(_:)),
            key: ""
        )
        menu.addItem(enable)
        self.enableMenuItem = enable

        menu.addItem(.separator())

        // 2. 設定…(Cmd+,)
        menu.addItem(makeItem(
            title: "設定…",
            action: #selector(openSettings(_:)),
            key: ","
        ))

        menu.addItem(.separator())

        // 3. About
        menu.addItem(makeItem(
            title: "Hotaru について…",
            action: #selector(openAbout(_:)),
            key: ""
        ))

        // 4. Quit
        menu.addItem(makeItem(
            title: "Hotaru を終了",
            action: #selector(quitApp(_:)),
            key: "q"
        ))

        return menu
    }

    // NSMenuItem 生成のヘルパ。target = self を必ずセット。
    private func makeItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func toggleTitle(for isEnabled: Bool) -> String {
        isEnabled ? "Hotaru を無効にする" : "Hotaru を有効にする"
    }

    // MARK: - Subscriptions

    private func subscribeToPreferences() {
        // isEnabled の変化にあわせて、メニュー項目の見出しを書き換える。
        // objectWillChange は "これから変わる" なので、RunLoop.main で 1 tick ずらして
        // 新しい値を読む(= 変更後のタイミングに合わせる)。
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.enableMenuItem?.title = self.toggleTitle(for: self.preferences.isEnabled)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: Any?) {
        preferences.isEnabled.toggle()
    }

    @objc private func openSettings(_ sender: Any?) {
        // SwiftUI の Settings シーン + showSettingsWindow: セレクタの経路は
        // LSUIElement アプリで安定しないため、自前の SettingsWindowController を使う。
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout(_ sender: Any?) {
        NSApp.activate()
        // About パネルは AppKit が持っている標準ダイアログ。
        // 特定の受信者を指定しなくても、NSApp が直接ハンドルする。
        NSApp.orderFrontStandardAboutPanel(sender)
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
}
