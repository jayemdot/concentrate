import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: SessionController!
    private var menuBar: MenuBarController!
    private let passcodePanel = PasscodePanelController()
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        session = SessionController()
        menuBar = MenuBarController(session: session)
        installTerminationHandler()
        // 起動ホットキーは将来 Raycast 連携側で設定する方針のため、本体では持たない。

        // 解除ホットキー(⌃⌥⌘P) → パスコードパネル → 正解で解除。
        session.onUnlockRequested = { [weak self] in
            guard let self else { return }
            self.passcodePanel.presentUnlock { [weak self] in
                self?.session.stop()
            }
        }

        // パスコード設定パネル。
        session.onSetupRequested = { [weak self] in
            guard let self else { return }
            self.passcodePanel.presentSetup { [weak self] in
                self?.session.refreshPasscode()
            }
        }

        // 権限が無ければ起動時に一度だけ案内する。
        if !ensureAccessibilityPermission(prompt: false) {
            session.requestPermission()
        }

        // 初回はパスコード設定が必須(未設定なら集中開始できない)。
        if !PasscodeStore.isSet {
            session.requestSetup()
        }
    }

    /// 通常終了(終了ボタン)では willTerminate で、`killall`(SIGTERM)では
    /// dispatch source で、イベントタップとスペース監視を綺麗に解除する。
    /// ※ プロセスが死ねばタップ/監視は消えるので、強制終了(SIGKILL)でも実害はない。
    private func installTerminationHandler() {
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { [weak self] in
            self?.session.stop()
            NSApp.terminate(nil)
        }
        src.resume()
        sigtermSource = src
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }
}
