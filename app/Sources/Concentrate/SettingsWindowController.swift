import AppKit
import SwiftUI

/// 設定ウィンドウ(SwiftUI を NSWindow に載せる)を管理する。
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(session: session))
        let w = NSWindow(contentViewController: hosting)
        w.title = "Concentrate 設定"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        window = w

        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }
}
