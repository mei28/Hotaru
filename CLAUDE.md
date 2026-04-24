# Hotaru

macOS のアクティブウィンドウの周囲に色付きボーダーを描画するメニューバー常駐アプリ。

## ドキュメント

- 仕様書: [`SPEC.md`](./SPEC.md)
- 現在のフェーズ: **メンテナンス**(Phase 0-8 完了、仕様書 §13 の将来拡張は未着手)

## 環境とスコープ

| 項目 | 値 |
|------|-----|
| 対応 OS | macOS 26 Tahoe(手元環境で動けば可、個人用途) |
| 言語 | Swift 5.9+ |
| UI | AppKit(メニューバー・オーバーレイ・AX API)+ SwiftUI(設定画面) |
| 永続化 | UserDefaults |
| 配布 | GitHub Release、個人用途のため署名・公証は不要 |

## 開発スタイル

- エディタ: **nvim** + `sourcekit-lsp` + `xcode-build-server`
- タスクランナー: `just`(全コマンドを `justfile` に集約)
- ビルド: CLI の `xcodebuild`
- Xcode.app は初回プロジェクト生成と GUI で触りたいときのみ使う

## 進行ルール

- **Phase 単位で進める**。次の Phase にジャンプしない
- 各 Phase の終わりでコミット
- AX API の C 関数呼び出しまわりは、投下前にロジックを口頭で説明する
- 実装に不確実な点があれば、質問してから書く(推測で進めない)

## ユーザー背景(AI 向けメモ)

- Swift は未経験だが、Python / TypeScript / Java / Rust の経験あり
- 抽象的なプログラミング概念の解説は不要
- Swift / AppKit 固有のイディオム、ARC、C 関数コールバック、`Unmanaged` などに解説を厚くする
- Rust の所有権とのアナロジーが有効な場面では併記する
- Swift 学習が目的の一つ。コードを動かすだけでなく、なぜそう書くかを理解したい

## ビルド・実行

```
just build       # ビルド
just run         # ビルド + 起動
just lsp         # sourcekit-lsp 用の設定生成
just doctor      # 環境チェック
```

詳細は `justfile` を参照。
