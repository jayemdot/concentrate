import CoreGraphics
import ApplicationServices
import os

/// CGEventTap を設置し、脱出キーを握り潰す。タップ無効化時は自動再有効化する。
final class EventTapBlocker {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let log = Logger(subsystem: "com.jayemdot.concentrate", category: "EventTap")

    /// 解除ホットキーが押されたときに呼ばれる(メインスレッドで実行される)。
    var onUnlockHotKey: (() -> Void)?

    var isRunning: Bool { tap != nil }

    /// タップを設置して開始する。権限不足などで失敗したら false。
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            log.error("イベントタップの作成に失敗(権限未許可の可能性)")
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        tap = newTap
        source = src
        log.info("イベントタップ開始")
        return true
    }

    /// タップを停止して片付ける。
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        log.info("イベントタップ停止")
    }

    /// システムにより無効化されたタップを再び有効化する(健全性監視)。
    fileprivate func reEnable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        log.notice("タップを再有効化しました")
    }
}

// @convention(c): ローカルキャプチャ禁止。コンテキストは refcon 経由で受け取る。
private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            Unmanaged<EventTapBlocker>.fromOpaque(refcon).takeUnretainedValue().reEnable()
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 解除ホットキー: パネル表示をメインで予約しつつ、キー自体は握り潰す。
        if FocusKeys.isUnlockHotKey(flags: flags, keyCode: keyCode) {
            if let refcon {
                let blocker = Unmanaged<EventTapBlocker>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async { blocker.onUnlockHotKey?() }
            }
            return nil
        }

        if FocusKeys.swallowLabel(flags: flags, keyCode: keyCode) != nil {
            return nil // 握り潰す
        }
    }

    return Unmanaged.passUnretained(event)
}
