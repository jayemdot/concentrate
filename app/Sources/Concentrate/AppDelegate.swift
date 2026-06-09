import AppKit
import Carbon // kInternetEventClass / kAEGetURL / keyDirectObject

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: SessionController!
    private var menuBar: MenuBarController!
    private var settingsWindow: SettingsWindowController!
    private let passcodePanel = PasscodePanelController()
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        session = SessionController()
        menuBar = MenuBarController(session: session)
        settingsWindow = SettingsWindowController(session: session)
        installTerminationHandler()
        registerURLHandler()
        // 起動ホットキーは将来 Raycast 連携側で設定する方針のため、本体では持たない。

        // 解除ホットキー(⌃⌥⌘P) → パスコードパネル → 正解で解除。
        session.onUnlockRequested = { [weak self] in
            guard let self else { return }
            self.passcodePanel.presentUnlock { [weak self] in
                self?.session.stop()
            }
        }

        // パスコード設定/変更パネル。
        session.onSetupRequested = { [weak self] in
            guard let self else { return }
            self.passcodePanel.presentSetup { [weak self] in
                self?.session.refreshPasscode()
            }
        }

        // 設定ウィンドウ。
        session.onSettingsRequested = { [weak self] in
            self?.settingsWindow.show()
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

    // MARK: - URL スキーム (concentrate://)

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        handle(url)
    }

    /// concentrate://focus?minutes=25 で開始、それ以外はポップオーバーを開く。
    private func handle(_ url: URL) {
        switch url.host {
        case "focus":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let value = comps?.queryItems?.first(where: { $0.name == "minutes" })?.value,
               let minutes = Int(value), session.canStart {
                session.start(minutes: minutes)
            } else {
                menuBar.showPopover()
            }
        default: // open / 不明
            menuBar.showPopover()
        }
    }

    // MARK: - 終了処理

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
