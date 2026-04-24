set shell := ["bash", "-ceuo", "pipefail"]

# プロジェクト設定
project       := "Hotaru"
scheme        := "Hotaru"
configuration := "Debug"
derived_data  := "./build"
# Xcode プロジェクトは Hotaru/ サブフォルダに入れ子
xcodeproj     := "Hotaru/Hotaru.xcodeproj"
app_path      := derived_data / "Build/Products" / configuration / (project + ".app")
release_app   := derived_data / "Build/Products/Release" / (project + ".app")
dist_dir      := "./dist"
subsystem     := "com.waddlier.Hotaru"

# デフォルト: レシピ一覧
default:
    @just --list

# 環境チェック(Phase 0 で最初に使う)
doctor:
    @echo "==== macOS ===="
    @sw_vers
    @echo
    @echo "==== xcode-select ===="
    @xcode-select -p
    @echo
    @echo "==== xcodebuild ===="
    @xcodebuild -version 2>&1 || echo "  ✗ xcodebuild 未利用可(Xcode.app が必要)"
    @echo
    @echo "==== swift ===="
    @swift --version 2>&1 || echo "  ✗ swift 未利用可"
    @echo
    @echo "==== sourcekit-lsp ===="
    @xcrun --find sourcekit-lsp 2>/dev/null && echo "  ✓ 利用可" || echo "  ✗ 未検出"
    @echo
    @echo "==== 補助ツール ===="
    @command -v just              >/dev/null && echo "  ✓ just"              || echo "  ✗ just"
    @command -v xcode-build-server >/dev/null && echo "  ✓ xcode-build-server" || echo "  ✗ xcode-build-server(brew install xcode-build-server)"
    @command -v xcbeautify        >/dev/null && echo "  ✓ xcbeautify"        || echo "  ✗ xcbeautify(brew install xcbeautify)"

# ビルド
# -destination を明示して、複数候補警告を抑止する
build:
    set -o pipefail && xcodebuild \
        -project {{xcodeproj}} \
        -scheme {{scheme}} \
        -configuration {{configuration}} \
        -destination "platform=macOS,arch=arm64" \
        -derivedDataPath {{derived_data}} \
        build | xcbeautify

# ビルドして起動(通常起動。stdout は捨てられる)
run: build
    open {{app_path}}

# 前景実行(ターミナルに stdout が流れるので print() の確認に使う)
# Ctrl+C で停止。メニューバーの Cmd+Q でも停止。
run-fg: build
    {{app_path}}/Contents/MacOS/{{project}}

# 日本語ロケールを強制して前景実行(ローカライゼーションの確認用)
run-ja: build
    {{app_path}}/Contents/MacOS/{{project}} -AppleLanguages '(ja)'

# 英語ロケールを強制して前景実行
run-en: build
    {{app_path}}/Contents/MacOS/{{project}} -AppleLanguages '(en)'

# os.Logger の出力を Console に流す(os_log / Logger で書いたものをリアルタイム表示)
log:
    log stream --predicate 'subsystem == "{{subsystem}}"' --level debug

# 成果物の場所を表示
where:
    @echo {{app_path}}

# クリーン
clean:
    rm -rf {{derived_data}} {{dist_dir}}

# Release ビルド + .zip 化(成果物: dist/Hotaru-<version>.zip)。
# GitHub Actions からも同じレシピを呼ぶので、ローカルと CI でパイプを統一できる。
release:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{dist_dir}}
    xcodebuild \
        -project {{xcodeproj}} \
        -scheme {{scheme}} \
        -configuration Release \
        -destination "platform=macOS,arch=arm64" \
        -derivedDataPath {{derived_data}} \
        build | xcbeautify
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "{{release_app}}/Contents/Info.plist")
    DIST="$PWD/{{dist_dir}}/{{project}}-${VERSION}.zip"
    rm -f "$DIST"
    (cd "$(dirname {{release_app}})" && zip -qry "$DIST" "$(basename {{release_app}})")
    echo "Wrote $DIST"

# pbxproj の MARKETING_VERSION を指定値に置換(例: just version 1.2.3)
version v:
    sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = {{v}};/' {{xcodeproj}}/project.pbxproj
    @grep -m 1 "MARKETING_VERSION" {{xcodeproj}}/project.pbxproj

# LSP 用の設定生成(xcode-build-server)
# nvim の sourcekit-lsp が .xcodeproj の補完を効かせるために必要
# buildServer.json はプロジェクトルートに生成される
lsp:
    xcode-build-server config -project {{xcodeproj}} -scheme {{scheme}}

# 初回セットアップのチェックリストを表示
setup:
    @echo "1) Xcode.app をインストール(App Store)"
    @echo "2) sudo xcode-select -s /Applications/Xcode.app"
    @echo "3) brew install just xcode-build-server xcbeautify"
    @echo "4) Xcode で Hotaru プロジェクトを生成(Phase 0 の手順参照)"
    @echo "5) just lsp   # nvim で補完を効かせる"
    @echo "6) just doctor # 環境確認"
