import Foundation
import AppKit
import Combine
import os

/// 集中セッションの状態機械。タイマーとイベントタップを束ねる。
@MainActor
final class SessionController: ObservableObject {
    enum State: Equatable {
        case idle
        case locked
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remaining: TimeInterval = 0
    /// セッションの総時間(リングの進捗計算用)。
    @Published private(set) var duration: TimeInterval = 0
    /// アクセシビリティ権限の有無(UI から監視できるよう @Published にする)。
    @Published private(set) var permissionGranted: Bool = ensureAccessibilityPermission(prompt: false)
    /// 解除用パスコードが設定済みか。
    @Published private(set) var passcodeSet: Bool = PasscodeStore.isSet
    /// ロック中に別スペースへ移ったら引き戻すか。
    @Published var bounceBackEnabled: Bool = (UserDefaults.standard.object(forKey: "bounceBackEnabled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(bounceBackEnabled, forKey: "bounceBackEnabled") }
    }

    /// 引き戻し先のヒント(メニューバーを開く直前の最前面アプリ)。
    var targetApp: NSRunningApplication?

    private let blocker = EventTapBlocker()
    private let spaceGuard = SpaceGuard()
    private var timer: Timer?
    private var endDate: Date?
    private let log = Logger(subsystem: "com.jayemdot.concentrate", category: "Session")

    /// SwiftUI 以外の購読者(メニューバー)向けの更新通知。
    var onChange: (() -> Void)?
    /// 解除ホットキーが押されたとき(= パスコードパネルを出してほしい)。
    var onUnlockRequested: (() -> Void)?
    /// パスコード設定を出してほしいとき。
    var onSetupRequested: (() -> Void)?
    /// 設定ウィンドウを出してほしいとき。
    var onSettingsRequested: (() -> Void)?

    init() {
        blocker.onUnlockHotKey = { [weak self] in
            self?.onUnlockRequested?()
        }
    }

    /// 残り時間の MM:SS 表記。
    var remainingText: String {
        let s = max(0, Int(remaining.rounded()))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// 残りの割合(1=満タン, 0=終了)。
    var progress: Double {
        duration > 0 ? max(0, min(1, remaining / duration)) : 0
    }

    /// セッションを開始できる条件がそろっているか。
    var canStart: Bool { permissionGranted && passcodeSet }

    // MARK: - 権限 / パスコードの状態取り込み

    func refreshPermission() {
        permissionGranted = ensureAccessibilityPermission(prompt: false)
    }

    func refreshPasscode() {
        passcodeSet = PasscodeStore.isSet
    }

    func requestPermission() {
        ensureAccessibilityPermission(prompt: true)
    }

    func requestSetup() {
        onSetupRequested?()
    }

    func requestSettings() {
        onSettingsRequested?()
    }

    /// パスコードパネルを出して解除を要求する(ロック中のUIボタン用)。
    func requestUnlock() {
        guard state == .locked else { return }
        onUnlockRequested?()
    }

    // MARK: - セッション制御

    func start(minutes: Int) {
        guard state == .idle else { return }
        guard canStart else {
            log.error("開始条件未達(権限またはパスコード未設定)")
            return
        }
        guard blocker.start() else {
            log.error("ブロッカー開始失敗。権限を要求します")
            requestPermission()
            return
        }

        let total = TimeInterval(minutes * 60)
        endDate = Date().addingTimeInterval(total)
        duration = total
        remaining = total
        state = .locked
        startTimer()
        if bounceBackEnabled {
            spaceGuard.start(lockedApp: targetApp ?? NSWorkspace.shared.frontmostApplication)
        }
        notify()
        log.info("セッション開始: \(minutes, privacy: .public)分")
    }

    /// セッション終了(タイマー満了 or パスコード解除)。
    func stop() {
        guard state == .locked else { return }
        timer?.invalidate()
        timer = nil
        endDate = nil
        blocker.stop()
        spaceGuard.stop()
        remaining = 0
        duration = 0
        state = .idle
        notify()
        log.info("セッション終了")
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            stop()
        } else {
            remaining = left
            notify()
        }
    }

    private func notify() {
        onChange?()
    }
}
