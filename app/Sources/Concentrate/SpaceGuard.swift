import AppKit
import os

/// ロック中に別スペース/フルスクリーンへ移動されたら、ロック対象アプリを
/// 再アクティブ化して引き戻す(バウンスバック)。
///
/// トラックパッドのスワイプは公開APIでは握り潰せず、defaults による無効化も
/// 即時反映されないため、「移動を検知して戻す」方式で実効的にスペース移動を封じる。
@MainActor
final class SpaceGuard {
    private let log = Logger(subsystem: "com.jayemdot.concentrate", category: "SpaceGuard")
    private var lockedApp: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private var bouncing = false

    var isRunning: Bool { observer != nil }

    /// 監視開始。lockedApp は引き戻し先(ロック開始時に最前面だったアプリ)。
    func start(lockedApp: NSRunningApplication?) {
        guard observer == nil else { return }
        self.lockedApp = lockedApp
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.bounceBackIfNeeded()
            }
        }
        log.info("スペース監視開始(対象: \(lockedApp?.localizedName ?? "不明", privacy: .public))")
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        lockedApp = nil
        bouncing = false
        log.info("スペース監視停止")
    }

    private func bounceBackIfNeeded() {
        guard let app = lockedApp, !bouncing else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication
        // すでにロック対象が最前面、または自分(パスコードパネル表示中など)なら何もしない。
        if frontmost?.processIdentifier == app.processIdentifier { return }
        if frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier { return }

        bouncing = true
        app.activate(options: [.activateAllWindows])
        // 引き戻し自体が再度スペース変更を発火するので、短時間は再入を抑止する。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.bouncing = false
        }
        log.info("別スペースを検知 → ロック対象へ引き戻し")
    }
}
