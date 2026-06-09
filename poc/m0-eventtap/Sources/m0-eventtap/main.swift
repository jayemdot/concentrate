import Foundation
import CoreGraphics
import ApplicationServices

// =============================================================
// Concentrate M0 PoC
//   CGEventTap で「他アプリ/他スペースへの脱出キー」を握り潰せるかを検証する。
//   強制終了系(⌘⌥Esc)は設計方針(FR-2a)により対象外。
// =============================================================

// タップが無効化されたときに再有効化するため、グローバルに参照を保持する。
var eventTap: CFMachPort?

// 押されたキーが「脱出経路」かどうかを判定し、該当すれば説明ラベルを返す。
func swallowLabel(flags: CGEventFlags, keyCode: Int64) -> String? {
    let cmd = flags.contains(.maskCommand)
    let ctrl = flags.contains(.maskControl)

    // 主要キーの keyCode(US配列基準)
    let tab: Int64 = 48, grave: Int64 = 50
    let left: Int64 = 123, right: Int64 = 124, up: Int64 = 126, down: Int64 = 125
    let h: Int64 = 4, m: Int64 = 46, q: Int64 = 12
    let digits: Set<Int64> = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29] // 1〜9,0

    if cmd && keyCode == tab { return "⌘Tab(アプリ切替)" }
    if cmd && keyCode == grave { return "⌘`(同一アプリ内ウィンドウ切替)" }
    if ctrl && keyCode == left { return "⌃←(左のスペースへ)" }
    if ctrl && keyCode == right { return "⌃→(右のスペースへ)" }
    if ctrl && keyCode == up { return "⌃↑(Mission Control)" }
    if ctrl && keyCode == down { return "⌃↓(App Exposé)" }
    if ctrl && digits.contains(keyCode) { return "⌃数字(番号指定スペースへ)" }
    if cmd && keyCode == h { return "⌘H(アプリを隠す)" }
    if cmd && keyCode == m { return "⌘M(最小化)" }
    if cmd && keyCode == q { return "⌘Q(アプリ終了)" }
    return nil
}

// イベントタップのコールバック(@convention(c) 互換: ローカルキャプチャ禁止)
let callback: CGEventTapCallBack = { _, type, event, _ in
    // システムがタップを無効化したら再有効化する(健全性監視の最小版)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            FileHandle.standardError.write(Data("⚠️ タップが無効化されたため再有効化しました\n".utf8))
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let label = swallowLabel(flags: event.flags, keyCode: keyCode) {
            print("🚫 握り潰し: \(label)  [keyCode=\(keyCode)]")
            return nil // ← nil を返すとイベントがシステムに伝播しない(swallow)
        }
    }
    return Unmanaged.passUnretained(event)
}

// アクセシビリティ権限を確認(未許可ならシステム設定への誘導ダイアログを出す)
func ensureAccessibility() -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
}

print("=== Concentrate M0 PoC: CGEventTap で脱出キーを握り潰す ===")

guard ensureAccessibility() else {
    print("""
    ❗ アクセシビリティ権限が未許可です。
       システム設定 > プライバシーとセキュリティ > アクセシビリティ で、
       このバイナリ(または起動元のターミナルアプリ)を有効にしてください。
       許可後にもう一度実行してください。
    """)
    exit(1)
}
print("✅ アクセシビリティ権限OK")

// keyDown のみ監視(タップ無効化通知はマスク不要で届く)
let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
) else {
    print("❌ イベントタップの作成に失敗(権限不足の可能性)。")
    exit(1)
}
eventTap = tap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("""
🟢 ロック中。次を試してください:
     ⌘Tab / ⌘`  … アプリ・ウィンドウ切替
     ⌃← / ⌃→ / ⌃↑ … スペース移動・Mission Control
   握り潰されたキーはここにログされます。
   ※ ⌘Q なども握り潰すため、終了は Ctrl-C で。
   ※ ⌘⌥Esc(強制終了)はわざと素通しします(設計方針 FR-2a)。
""")

CFRunLoopRun()
