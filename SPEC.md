# Hotaru 仕様書

> macOSのアクティブウィンドウの周囲に柔らかい光（色付きのボーダー）を灯すメニューバーアプリ

---

## 1. コンセプト

蛍のように、今自分が作業しているウィンドウをそっと照らし続けるアプリ。macOS Tahoe（Liquid Glass）以降、アクティブウィンドウと非アクティブウィンドウの見分けがつきにくくなった問題を、常時表示のカラーボーダーで解決する。

設計の核：

- **静かで邪魔にならない** — 機能はシンプル、UIは最小限
- **すぐに効果がわかる** — インストール直後から動く
- **カスタマイズ可能** — 色と幅は好みに合わせられる

---

## 2. 機能要件

### 2.1 コア機能

| ID | 機能 | 説明 |
|----|------|------|
| F-01 | アクティブウィンドウ検出 | フロントアプリの最前面ウィンドウを常時追跡する |
| F-02 | ボーダー描画 | 検出したウィンドウの外周に指定色のボーダーを描画する |
| F-03 | 追従 | ウィンドウの移動・リサイズにリアルタイムで追従する |
| F-04 | 切り替え追従 | アプリ切り替え、ウィンドウ切り替え時に即座にボーダーを移動する |
| F-05 | メニューバー常駐 | Dockにアイコンを出さず、メニューバーのみで動作する |
| F-06 | 設定画面 | ボーダーの色と幅を変更できる |
| F-07 | 有効／無効トグル | メニューバーから素早くON/OFFできる |
| F-08 | 設定の永続化 | アプリ再起動後も設定が維持される |

### 2.2 設定項目（標準構成）

- **ボーダー色（ライトモード）** — デフォルト: `#FFB84D`（蛍を思わせる温かい黄）
- **ボーダー色（ダークモード）** — デフォルト: `#7FFF6B`（蛍の発光色に近い黄緑）
- **ボーダーの幅** — 1〜10px、デフォルト: 3px
- **有効／無効** — デフォルト: 有効
- **ログイン時に自動起動** — デフォルト: 有効

### 2.3 非機能要件

- **対応OS**: macOS 13 Ventura 以降（推奨: macOS 14以降）
- **パフォーマンス**: ウィンドウ移動時のCPU使用率1%以下を目標
- **メモリ**: 50MB以下を目標
- **電力**: バックグラウンドで過度にCPUを使わない

---

## 3. 画面仕様

### 3.1 メニューバーアイコン

- メニューバーに蛍のアイコン（SF Symbols: `sparkle` や `light.beacon.max` など仮。後で差し替え可能）
- クリックでメニューを表示:
  - `Hotaruを有効にする` / `無効にする`（トグル）
  - `---`
  - `設定...` → 設定ウィンドウを開く
  - `ログイン時に起動`（チェック項目）
  - `---`
  - `Hotaruについて...`
  - `Hotaruを終了`

### 3.2 設定ウィンドウ

- サイズ: 480 × 360 程度
- タブなしの1画面でOK
- 構成:
  - ボーダーの色（ライトモード） — `NSColorWell` または SwiftUI の `ColorPicker`
  - ボーダーの色（ダークモード） — 同上
  - ボーダーの幅 — スライダー（1〜10px）+ 数値表示
  - プレビュー — 設定値をリアルタイムに反映する小さな矩形
  - 「デフォルトに戻す」ボタン

### 3.3 権限リクエスト画面

Accessibility権限がない場合、初回起動時または設定画面上部に案内を表示：

```
Hotaruがウィンドウを検出するには、アクセシビリティ権限が必要です。
[システム設定を開く]
```

---

## 4. 技術スタック

| 項目 | 選定 | 理由 |
|------|------|------|
| 言語 | Swift 5.9+ | AppKitの最新機能を使える |
| UIフレームワーク | **AppKit + SwiftUI混合** | メニューバーと設定画面はSwiftUIでOK、オーバーレイはAppKit |
| 最小デプロイターゲット | macOS 13.0 | SwiftUIの成熟度 |
| 永続化 | `UserDefaults` | 設定項目が少ないので十分 |
| ビルド | Xcode 15+ | |

### なぜSwiftUIだけで作らないか

オーバーレイウィンドウ（`NSWindow` の細かい設定）と Accessibility API は AppKit/Core Foundation の世界なので、ここはどうしても AppKit が必要になる。設定画面など静的なUIは SwiftUI の方が圧倒的に書きやすいので、**責務で分ける**方針。

---

## 5. アーキテクチャ

### 5.1 ファイル構成

```
Hotaru/
├── HotaruApp.swift              # @main エントリポイント
├── AppDelegate.swift             # NSApplicationDelegate、起動時処理
│
├── Core/
│   ├── FocusTracker.swift        # アクティブアプリ/ウィンドウの追跡
│   ├── WindowObserver.swift      # AXObserverで移動・リサイズを監視
│   └── AccessibilityChecker.swift # 権限チェックとリクエスト
│
├── Overlay/
│   ├── OverlayWindow.swift       # ボーダー表示用の透明NSWindow
│   ├── OverlayView.swift         # ボーダーを描画するNSView
│   └── OverlayController.swift   # オーバーレイの表示・非表示・移動制御
│
├── Settings/
│   ├── SettingsWindow.swift      # 設定ウィンドウ（SwiftUIホスト）
│   ├── SettingsView.swift        # SwiftUIのメインビュー
│   └── Preferences.swift         # UserDefaultsラッパー
│
├── MenuBar/
│   └── MenuBarController.swift   # NSStatusItemとメニュー管理
│
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

### 5.2 主要クラスの責務

| クラス | 責務 |
|--------|------|
| `AppDelegate` | アプリ全体のライフサイクル、各コントローラの初期化 |
| `MenuBarController` | メニューバーアイコンとメニューの管理 |
| `AccessibilityChecker` | AX権限の確認、システム設定への誘導 |
| `FocusTracker` | `NSWorkspace` でフロントアプリを監視 |
| `WindowObserver` | `AXObserver` でウィンドウの移動・リサイズを監視 |
| `OverlayController` | 検出したウィンドウ位置にオーバーレイを表示 |
| `OverlayWindow` / `OverlayView` | 透明ウィンドウ + ボーダー描画 |
| `Preferences` | 設定値の読み書き（UserDefaults） |
| `SettingsView` | SwiftUIによる設定画面 |

### 5.3 データフロー

```
[ユーザーがウィンドウ切り替え]
        ↓
NSWorkspace.didActivateApplicationNotification
        ↓
FocusTracker がフロントアプリを検出
        ↓
AXUIElementCopyAttributeValue(kAXFocusedWindowAttribute)
        ↓
ウィンドウ座標を取得 (kAXPositionAttribute / kAXSizeAttribute)
        ↓
WindowObserver が AXObserver を登録
        ↓
OverlayController がオーバーレイの位置と表示を更新
        ↓
OverlayView がボーダーを描画

[ウィンドウの移動・リサイズ]
        ↓
AXObserver が kAXMovedNotification / kAXResizedNotification を発火
        ↓
OverlayController が位置を追従
```

---

## 6. データモデル

### 6.1 UserDefaults キー

```swift
enum PreferenceKey: String {
    case isEnabled = "hotaru.isEnabled"
    case borderColorLight = "hotaru.borderColor.light"
    case borderColorDark = "hotaru.borderColor.dark"
    case borderWidth = "hotaru.borderWidth"
    case launchAtLogin = "hotaru.launchAtLogin"
}
```

カラーは `NSColor` を `NSKeyedArchiver` でData化して保存するか、RGBAの数値で保存する。後者の方がデバッグしやすい。

---

## 7. 実装の重要ポイント

### 7.1 Accessibility権限

- チェック: `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)`
- 設定画面への誘導: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`
- 権限がないと何もできないので、起動時に必ずチェック
- **ハマりポイント**: Xcodeで開発中にコード署名が変わると権限がリセットされるので、設定で一度削除して再付与が必要になる

### 7.2 フロントアプリの監視

```swift
NSWorkspace.shared.notificationCenter.addObserver(
    self,
    selector: #selector(appDidActivate(_:)),
    name: NSWorkspace.didActivateApplicationNotification,
    object: nil
)
```

### 7.3 アクティブウィンドウの取得

```swift
let appElement = AXUIElementCreateApplication(pid)
var focusedWindow: CFTypeRef?
AXUIElementCopyAttributeValue(
    appElement,
    kAXFocusedWindowAttribute as CFString,
    &focusedWindow
)
// focusedWindow を AXUIElement として扱う
```

### 7.4 座標とサイズ

- 取得値は `CGPoint` / `CGSize`
- **macOSのAX座標系は画面左上が原点**（Cocoaの座標系は左下原点なので注意）
- 変換が必要: `y = primaryScreenHeight - axY - windowHeight`

### 7.5 オーバーレイウィンドウの設定

```swift
let window = NSWindow(
    contentRect: frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.ignoresMouseEvents = true                    // クリックをスルー
window.level = .statusBar                            // 前面に表示
window.collectionBehavior = [
    .canJoinAllSpaces,                               // 全Spaceに表示
    .fullScreenAuxiliary,                            // フルスクリーンにも出る
    .stationary                                      // ミッションコントロールで動かない
]
```

### 7.6 ウィンドウ移動・リサイズの追従

```swift
var observer: AXObserver?
AXObserverCreate(pid, callback, &observer)
AXObserverAddNotification(
    observer!,
    windowElement,
    kAXMovedNotification as CFString,
    context
)
AXObserverAddNotification(
    observer!,
    windowElement,
    kAXResizedNotification as CFString,
    context
)
CFRunLoopAddSource(
    CFRunLoopGetCurrent(),
    AXObserverGetRunLoopSource(observer!),
    .defaultMode
)
```

コールバックはC関数ポインタなので、`self` を渡すのに `Unmanaged.passUnretained(self).toOpaque()` を使う。

### 7.7 ボーダー描画

`OverlayView` を作り、`CALayer` に直接設定するのが最もシンプル：

```swift
view.wantsLayer = true
view.layer?.borderColor = borderColor.cgColor
view.layer?.borderWidth = borderWidth
view.layer?.cornerRadius = 10  // macOSの角丸に合わせる場合
```

**注意**: macOS Tahoe以降、ウィンドウの角丸は実際には取得できない。おおよそ `10〜12px` で固定するか、0でシンプルな矩形にする。

---

## 8. エッジケース

| ケース | 対応 |
|--------|------|
| アクティブウィンドウがない（全最小化） | オーバーレイを非表示 |
| Finderのデスクトップ | オーバーレイを非表示（ウィンドウが取れない） |
| フルスクリーンアプリ | `fullScreenAuxiliary` で追従可能、ただしメニューバー表示には注意 |
| Spaces切り替え | `canJoinAllSpaces` で追従 |
| マルチディスプレイ | ウィンドウがあるスクリーンに表示（`NSScreen.screens` から判定） |
| ディスプレイスリープ復帰 | 再度フロントアプリを検出して再配置 |
| アプリが応答しない | AX呼び出しがタイムアウトする場合があるので、タイムアウト制御を検討 |
| Apple純正のアラート・シート | 親ウィンドウにボーダーを表示し続ける（シート自体は取得しづらい）|

---

## 9. 開発フェーズ

**段階的に動くものを作る**のが初学者には最も効果的。各フェーズごとに動作確認できる区切りを設ける。

### Phase 0: プロジェクト作成（30分）
- Xcodeで新規プロジェクト作成（macOS App、SwiftUI、Swift）
- `Info.plist` に `LSUIElement = YES` を追加（Dockアイコン非表示）
- Git初期化

### Phase 1: メニューバー常駐アプリ（1〜2時間）
- `NSStatusItem` でメニューバーアイコン表示
- クリックでメニュー表示
- 「終了」メニューで終了できる
- **ここで一度コミット**

### Phase 2: Accessibility権限（1時間）
- 起動時に権限チェック
- なければダイアログ表示とシステム設定への誘導
- 権限付与後の再起動フロー

### Phase 3: フロントアプリ検出（1〜2時間）
- `NSWorkspace` でアプリ切り替えを検出
- コンソールに切り替わったアプリ名を出力
- **まだオーバーレイは作らない、ログだけ**

### Phase 4: アクティブウィンドウの座標取得（2〜3時間）
- AX APIでフォーカスウィンドウの位置とサイズを取得
- 座標系の変換を正しく実装
- コンソールに座標を出力して検証

### Phase 5: オーバーレイ表示（2〜3時間）
- 透明な `NSWindow` を作成
- `CALayer` のボーダーで矩形を描画
- 取得した座標にオーバーレイを配置
- **ここで初めて見た目の変化が出る**

### Phase 6: 移動・リサイズ追従（2〜3時間）
- `AXObserver` を使って通知を受け取る
- コールバックでオーバーレイを再配置
- この段階でだいたい実用的になる

### Phase 7: 設定画面（2〜3時間）
- SwiftUIで設定ビュー作成
- `UserDefaults` との連携
- 色・幅の変更がリアルタイムで反映される

### Phase 8: 仕上げ（2〜4時間）
- ログイン起動（`ServiceManagement` の `SMAppService`）
- マルチディスプレイ対応の詰め
- フルスクリーン挙動の確認
- メニューバーアイコンの整備

**合計**: 初学者で 15〜25時間程度を見込む。

---

## 10. Claude Codeとの進め方ガイド

### 10.1 最初にやること

プロジェクトのルートに `CLAUDE.md` を置く。これは Claude Code がセッション開始時に自動で読むファイル：

```markdown
# Hotaru

このプロジェクトはmacOSのアクティブウィンドウを色付きボーダーで強調するメニューバーアプリです。

## 重要
- 仕様は `Hotaru-spec.md` を参照してください
- 現在のフェーズ: Phase X（進捗に応じて更新）
- 対応OS: macOS 13+
- Swift + AppKit + SwiftUI混合

## 開発ルール
- 新しい機能は必ずPhase単位で進める
- 各Phaseの終わりにコミットする
- Accessibility APIのC関数呼び出しは特に慎重にレビュー
- 質問があれば必ず聞いてから進める
```

仕様書（このファイル）も一緒に配置しておく。

### 10.2 フェーズごとの最初のプロンプト例

**Phase 1 の開始:**

> `Hotaru-spec.md` のPhase 1を実装したいです。
> `NSStatusItem` でメニューバーアイコンを出し、クリックでメニューを表示、
> 「Hotaruを終了」で終了できる最小構成のコードを書いてください。
> 私はSwift/AppKitは初めてなので、各ファイルの役割と、重要な行にはコメントを日本語で入れてください。

**Phase 4 の開始:**

> Phase 3まで完了しています。次はPhase 4、
> AX APIを使ってアクティブウィンドウの座標とサイズを取得します。
> 仕様書の7.3〜7.4を参考に、`FocusTracker.swift` を実装してください。
> 取得した座標を `print` で出力して動作確認できるようにしてください。
> C関数のコールバックで `self` を渡す部分は特に解説をお願いします。

### 10.3 良いプロンプトのコツ

- **一度に大きな範囲を任せない** — 1フェーズずつ
- **参照先を明示する** — 「仕様書の7.5節」のように指定
- **動作確認方法を含める** — 「`print` で出力」「手動でテストする手順」
- **理解したい箇所は明示する** — 「AXObserverの部分を説明してください」

### 10.4 Claude Codeに任せていいこと・人間が判断すべきこと

**任せていい:**
- ボイラープレートコード（AppDelegate、基本的なNSWindowセットアップなど）
- SwiftUIの設定ビュー
- UserDefaultsのラッパー

**自分で理解・判断したい:**
- AX APIの呼び出し（権限まわり、メモリ管理）
- 座標系の変換ロジック
- オブザーバーのライフサイクル管理

あとの「理解したい部分」は、Claude Codeに書かせてから**「この関数を1行ずつ説明して」**と聞くのが一番学びになる。

---

## 11. 学習リソース

### Swift / AppKit の基礎

- **Apple公式**: [AppKit ドキュメント](https://developer.apple.com/documentation/appkit)
- **書籍**: "macOS by Tutorials"（raywenderlich.com、Kodeco）
- **YouTube**: Sean Allen、Paul Hudson（Hacking with Swift）

### Accessibility API

- Apple公式: [Accessibility for macOS](https://developer.apple.com/documentation/applicationservices/axuielement)
- **参考になるOSSリポジトリ**:
  - [tylerhall/Alan](https://github.com/tylerhall/Alan) — 同じ目的のアプリ、ソースを読むと早い
  - [koekeishiya/yabai](https://github.com/koekeishiya/yabai) — ウィンドウマネージャ、AX APIの使い方の参考

### SwiftUI 基礎

- Apple公式: [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- Paul Hudson: [Hacking with SwiftUI](https://www.hackingwithswift.com/quick-start/swiftui)

---

## 12. 次のステップ

1. **Xcodeをインストール**（App Storeから、まだなら）
2. **プロジェクトを作成**（Phase 0）
3. **この仕様書と `CLAUDE.md` をプロジェクトルートに配置**
4. **Claude Codeを起動してPhase 1から開始**
5. 各フェーズが完了したら、動作確認 → コミット → 次フェーズへ

---

## 13. 将来の拡張アイデア

標準構成を作り終えたら、以下のような拡張が考えられます（無理に今入れる必要はない）：

- **アプリごとの色設定** — Xcodeは青、Chromeは緑、など
- **Hanabiモード** — 切り替え時に一瞬パッと光るアニメーション
- **ボーダースタイル** — 実線・点線・グラデーション
- **角丸の自動調整** — ウィンドウの角丸に合わせる
- **メニューバーからクイック色変更** — よく使う3色をメニューから即切り替え
- **Keyboard Maestro / Shortcuts連携** — フォーカス時間の記録など

---

**バージョン**: 1.0  
**作成日**: 2026-04-23
