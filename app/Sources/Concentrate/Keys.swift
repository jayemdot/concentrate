import CoreGraphics
import ApplicationServices

// 「他アプリ/他スペースへの脱出キー」の定義と判定をまとめる。
// 強制終了系(⌘⌥Esc)は設計方針 FR-2a により対象に含めない。
enum FocusKeys {
    // 主要キーの keyCode(US配列基準)
    private static let tab: Int64 = 48
    private static let grave: Int64 = 50
    private static let left: Int64 = 123
    private static let right: Int64 = 124
    private static let up: Int64 = 126
    private static let down: Int64 = 125
    private static let h: Int64 = 4
    private static let m: Int64 = 46
    private static let q: Int64 = 12
    private static let digits: Set<Int64> = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29] // 1〜9,0

    /// 押されたキーが脱出経路なら説明ラベルを、そうでなければ nil を返す。
    static func swallowLabel(flags: CGEventFlags, keyCode: Int64) -> String? {
        let cmd = flags.contains(.maskCommand)
        let ctrl = flags.contains(.maskControl)

        if cmd && keyCode == tab { return "⌘Tab" }
        if cmd && keyCode == grave { return "⌘`" }
        if ctrl && keyCode == left { return "⌃←" }
        if ctrl && keyCode == right { return "⌃→" }
        if ctrl && keyCode == up { return "⌃↑" }
        if ctrl && keyCode == down { return "⌃↓" }
        if ctrl && digits.contains(keyCode) { return "⌃数字" }
        if cmd && keyCode == h { return "⌘H" }
        if cmd && keyCode == m { return "⌘M" }
        if cmd && keyCode == q { return "⌘Q" }
        return nil
    }

    private static let p: Int64 = 35 // P

    /// 解除ホットキー(⌃⌥⌘P)かどうか。ロック中の解除パネル呼び出しに使う。
    /// 脱出キーとは衝突しない組み合わせにしてある。
    static func isUnlockHotKey(flags: CGEventFlags, keyCode: Int64) -> Bool {
        flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && flags.contains(.maskCommand)
            && keyCode == p
    }
}

/// アクセシビリティ権限を確認する。prompt=true ならシステム設定への誘導ダイアログを出す。
@discardableResult
func ensureAccessibilityPermission(prompt: Bool) -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
}
