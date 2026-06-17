import AppKit
import SwiftUI

/// メニューバー常駐アイコンとポップオーバーを管理する。
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let session: SessionController
    private var wasLocked = false

    init(session: SessionController) {
        self.session = session
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        configurePopover()
        session.onChange = { [weak self] in self?.sessionDidChange() }
        updateButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        button.target = self
        button.imagePosition = .imageLeading
        // カウントダウン表示で桁幅が揺れないよう等幅数字フォントにする。
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    private func configurePopover() {
        popover.behavior = .transient
        // 開くアニメーションを切ると初期位置・サイズのガタつきが消える。
        popover.animates = false
        let hosting = NSHostingController(rootView: FocusView(session: session))
        // 中身のサイズに正しく追従させる。
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    private func sessionDidChange() {
        updateButton()
        // 「待機→集中中」に切り替わった瞬間だけポップオーバーを閉じる。
        // (毎ティックで閉じると、ロック中に開いた直後に消えてしまうため)
        let isLocked = session.state == .locked
        if isLocked, !wasLocked, popover.isShown {
            popover.performClose(nil)
        }
        wasLocked = isLocked
    }

    /// 状態に応じてメニューバー表示を更新する。
    private func updateButton() {
        guard let button = statusItem.button else { return }
        switch session.state {
        case .idle:
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Concentrate")
            button.title = ""
        case .locked:
            button.image = Self.ringImage(progress: session.progress)
            button.imagePosition = .imageLeading
            button.title = " \(session.remainingText)"
        }
    }

    /// メニューバー用の進捗リング(テンプレート画像=メニューバー色に追従)。
    private static func ringImage(progress: Double) -> NSImage {
        let side: CGFloat = 15
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let inset: CGFloat = 1.5
            let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 2
            NSColor.black.withAlphaComponent(0.25).setStroke()
            track.stroke()

            let start: CGFloat = 90
            let end = start - CGFloat(max(0, min(1, progress)) * 360)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            arc.lineWidth = 2
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    /// ポップオーバーを表示し、キーボードフォーカスを当てる。
    func showPopover() {
        guard let button = statusItem.button else { return }
        // 設定で権限/パスコードを変更した直後でも反映されるよう、表示前に最新化する。
        session.refreshPermission()
        session.refreshPasscode()
        // 引き戻し先のヒントとして、アクティブ化する前の最前面アプリを記録する。
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            session.targetApp = front
        }
        // accessory アプリはアクティブ化してから出さないと位置が乱れることがある。
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // 表示直後にポップオーバーのウィンドウをキーにしてフォーカスを当てる。
        popover.contentViewController?.view.window?.makeKey()
    }
}
