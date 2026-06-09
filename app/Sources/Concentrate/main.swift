import AppKit

// 起動時のトップレベルコードはメインスレッド上で動くため、
// MainActor 隔離を明示してから AppKit を初期化する。
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Dock に出さないメニューバー常駐アプリにする(Info.plist の LSUIElement と対応)。
    app.setActivationPolicy(.accessory)
    app.run()
}
