import Foundation

// AX 経由で取得したウィンドウ情報の Swift 側表現。
// ここでの position は "AX 座標系"(プライマリスクリーン左上が原点、Y 軸下向き)。
// Cocoa 座標系への変換は ScreenGeometry 側で行う。
//
// struct にしているのは値型(コピー時に内容複製、他の誰かが書き換えない)で扱いたいから。
// class にすると同じインスタンスを共有することになり、状態追跡が面倒になる。
// Rust の struct(= 値型)と同じ感覚。
struct WindowInfo: Equatable {
    let position: CGPoint  // AX 座標系
    let size: CGSize

    var frame: CGRect {
        CGRect(origin: position, size: size)
    }
}
