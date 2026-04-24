import ApplicationServices
import CoreGraphics

// Accessibility API を使って、指定 pid のアクティブウィンドウの位置・サイズを取得する。
// Phase 4 の中心。この先 Phase 6 で AXObserver(移動・リサイズの通知購読)に拡張していく。
//
// AX API は Objective-C のランタイム層ではなく、更に下位の C 層(Core Foundation)。
// したがって Swift からは:
//   - CFTypeRef / AXValue / AXUIElement といった CF 型が直接出てくる
//   - out パラメータは UnsafeMutablePointer<...> を要求する(Swift では `&var` で inout 渡し)
//   - エラーは AXError 列挙体で返ってくる
// といった "C っぽさ" が残る。Rust で言うと FFI 越しに C 構造体を触る感覚。
enum AXWindowQuery {

    // 指定 pid のアクティブアプリのフォーカスウィンドウ情報を AX 座標系で返す。
    // 失敗要因(すべて nil 返し):
    //   - AX 権限がない
    //   - アプリが応答しない / ウィンドウが無い
    //   - Electron アプリなど AX ツリーが貧弱でフォーカスウィンドウが取れない
    static func focusedWindowInfo(pid: pid_t) -> WindowInfo? {
        // pid からアプリのルート AX 要素を作る。戻り値は AXUIElement 型(CF 型)。
        // AXUIElementCreate*系の関数は "Create/Copy" 命名規約なので本来 Retain 済みだが、
        // Swift 側は ARC で自動解放される仕組みに包まれている。
        let appElement = AXUIElementCreateApplication(pid)

        // アプリ → フォーカスウィンドウ(= 最前面でアクティブなウィンドウ)を取り出す
        guard let windowElement = copyElement(
            from: appElement,
            attribute: kAXFocusedWindowAttribute
        ) else {
            return nil
        }

        // ウィンドウ → 位置とサイズ(それぞれ AXValue にラップされた CGPoint / CGSize)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard copyAXValueInto(
                &position,
                from: windowElement,
                attribute: kAXPositionAttribute,
                valueType: .cgPoint
              ),
              copyAXValueInto(
                &size,
                from: windowElement,
                attribute: kAXSizeAttribute,
                valueType: .cgSize
              )
        else {
            return nil
        }

        return WindowInfo(position: position, size: size)
    }

    // MARK: - 低レベル AX 呼び出しラッパ

    // AX 属性が AXUIElement(ウィンドウ、ボタン等の "参照" 型)を返す場合のラッパ。
    //
    // AXUIElementCopyAttributeValue は C 関数で、out パラメータとして
    // UnsafeMutablePointer<CFTypeRef?> を受け取る。
    // Swift では「Optional な var に `&` を付ければ inout ポインタになる」という糖衣があり、
    // CFTypeRef? 型の変数を宣言して `&value` と渡せば自動的にブリッジされる。
    private static func copyElement(from element: AXUIElement, attribute: String) -> AXUIElement? {
        var rawValue: CFTypeRef?  // CFTypeRef = AnyObject、あらゆる CF 型の共通親
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)

        // err は AXError(enum)。.success 以外はすべて失敗扱い。
        // よくあるエラー:
        //   .apiDisabled ... AX 機能が OS 側で無効
        //   .cannotComplete ... 権限不足、対象プロセス応答なし
        //   .attributeUnsupported ... その要素がこの属性を持たない
        //   .noValue ... 値が未設定
        guard err == .success, let value = rawValue else { return nil }

        // 属性名から型が確定しているので force cast で AXUIElement に落とす。
        // as! は失敗時 crash。推測でなく型が確実な場面のみ使う。
        return (value as! AXUIElement)
    }

    // AX 属性が AXValue ラップ(CGPoint / CGSize / CGRect / CFRange など)の場合のラッパ。
    //
    // ジェネリクス + inout の組み合わせ:
    //   - T は呼び出し側が持っている受け皿の型
    //   - AXValueGetValue は C 関数で、書き込み先のポインタを要求する
    //   - inout result の `&result` でポインタ化して渡す
    //
    // この関数は成功/失敗を Bool で返し、値は inout 先に直接書き込む。
    // Rust だと fn f(out: &mut T) -> bool のイメージ。
    private static func copyAXValueInto<T>(
        _ result: inout T,
        from element: AXUIElement,
        attribute: String,
        valueType: AXValueType
    ) -> Bool {
        var rawValue: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard err == .success, let value = rawValue else { return false }

        // 中身は AXValue(CGPoint/CGSize などの "不透明コンテナ")。
        // AXValueGetValue で `valueType` に合う形で書き出させる。
        // valueType と T の組み合わせがミスマッチでも AXValueGetValue が false を返して済む。
        let axValue = value as! AXValue
        return AXValueGetValue(axValue, valueType, &result)
    }
}
