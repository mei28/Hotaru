import AppKit
import ApplicationServices  // AX* 関数群はここ(AppKit が間接的に取り込むが明示しておく)

// アクセシビリティ権限の有無を確認し、必要なら UI 誘導を出すユーティリティ。
// Phase 2 では権限ゲートだけ。実際の AX API(ウィンドウ取得)は Phase 4 から。
//
// enum + static のパターンは Swift で「インスタンス化不可の純粋ユーティリティ」を
// 型レベルで宣言する慣習。case を定義していない enum は値を生成できないので、
// 誤って `AccessibilityChecker()` と書かれる心配がない。
// (Java の final class + private コンストラクタ、Rust の uninhabited enum に近い)
enum AccessibilityChecker {

    // 現在権限があるかだけを調べる(副作用なし・ダイアログも出ない)。
    // 起動後に UI から任意のタイミングで確認したい時に使う。
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    // 権限を要求する。初回の呼び出しでは macOS 標準の許可ダイアログが出て、
    // 同時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」の
    // リストに Hotaru が登録される(= ユーザーがオンに切り替えやすくなる)。
    //
    // 2 回目以降は既に登録済みなので、OS 側のダイアログは出ない。
    // 返り値は「このタイミングで trusted か」― ダイアログを出した直後は通常 false。
    @discardableResult
    static func requestTrust() -> Bool {
        // kAXTrustedCheckOptionPrompt は C 側では CFStringRef 定数だが、
        // Swift には Unmanaged<CFString> として入ってくる。
        // Unmanaged<T> = "ARC の管理外にある参照" を表す型で、
        // C 関数が返す raw pointer を「誰が所有するか」が曖昧な場面で使われる。
        //
        // .takeUnretainedValue() は「参照カウントを上げずに中身を取り出す」操作。
        // 定数なので誰も所有していない扱い = 参照カウントに触れないのが正解。
        // (もし Create/Copy 系の C 関数が返した Unmanaged なら
        //  .takeRetainedValue() を使い、カウントを引き取りながら取り出す。
        //  Rust で C から受け取った raw ptr を Box::from_raw で所有するかどうかの判断に近い)
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()

        // Swift Dictionary から CFDictionary への "toll-free bridging"。
        // CFString / CFBoolean 系はそのまま Swift の String / Bool と相互変換できる。
        let options: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // macOS の「システム設定 > プライバシーとセキュリティ > アクセシビリティ」を開く。
    // x-apple.systempreferences: は macOS が提供する深いリンク用 URL スキーム。
    static func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // 権限がなければ自前の説明アラートを出し、OK ならシステム設定へ誘導する。
    // @MainActor は「この関数はメインスレッド専用」のコンパイル時保証。
    // NSAlert などの AppKit UI はメインスレッドでしか触れないので、他スレッドからの
    // 呼び出しはコンパイルエラーにしてもらう。
    @MainActor
    static func requestAccessIfNeeded() {
        guard !isTrusted else { return }

        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
        Hotaru はアクティブウィンドウを検出するためにアクセシビリティ権限を必要とします。
        「システム設定を開く」を押し、リスト内の Hotaru をオンにしたあと、
        Hotaru を一度終了して再起動してください。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "システム設定を開く")  // returns .alertFirstButtonReturn
        alert.addButton(withTitle: "あとで")              // returns .alertSecondButtonReturn

        // runModal() は押下までブロックする同期モーダル。
        // 返り値は NSApplication.ModalResponse(.alertFirstButtonReturn など)。
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // requestTrust() を一度呼ぶことで、アプリがリストに登録される(= 初回のみ効果あり)。
            // その後 openSystemSettings() で設定画面に飛ばす。
            _ = requestTrust()
            openSystemSettings()
        }
    }
}
