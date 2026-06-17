import AppKit
import SwiftUI

/// パスコード関連のフローティングパネル(設定 / 解除)を管理する。
/// フルスクリーンアプリの上にも表示できるよう collectionBehavior を設定する。
@MainActor
final class PasscodePanelController {
    private var panel: NSPanel?

    /// 解除用パスコード入力を表示。正しく入力されたら onUnlock を呼ぶ。
    func presentUnlock(onUnlock: @escaping () -> Void) {
        let view = PasscodeEntryView(
            onSubmit: { PasscodeStore.verify($0) },
            onAccepted: { [weak self] in
                onUnlock()
                self?.close()
            },
            onCancel: { [weak self] in self?.close() }
        )
        present(view)
    }

    /// 初回パスコード設定を表示。設定完了で onDone を呼ぶ。
    func presentSetup(onDone: @escaping () -> Void) {
        let view = PasscodeSetupView(
            onSave: { PasscodeStore.set($0) },
            onSaved: { [weak self] in
                onDone()
                self?.close()
            }
        )
        present(view)
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func present<V: View>(_ view: V) {
        close()
        let hosting = NSHostingController(rootView: view.tint(.indigo))
        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable, .fullSizeContentView]
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.center()
        panel = p

        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
    }
}

/// 鍵バッジ(indigo グラデの円 + lock.fill)。
private struct LockBadge: View {
    var body: some View {
        Circle()
            .fill(Theme.accentGradient)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: Theme.accent.opacity(0.4), radius: 6, y: 2)
    }
}

// MARK: - 解除入力

struct PasscodeEntryView: View {
    var onSubmit: (String) -> Bool
    var onAccepted: () -> Void
    var onCancel: () -> Void

    @State private var code = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            LockBadge()

            VStack(spacing: 4) {
                Text("ロックを解除")
                    .font(.system(size: 15, weight: .semibold))
                Text("パスコードを入力してください")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            SecureField("パスコード", text: $code)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)

            if showError {
                Text("パスコードが違います")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("解除", action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 280)
        .background(.regularMaterial)
        .onAppear { focused = true }
    }

    private func submit() {
        if onSubmit(code) {
            onAccepted()
        } else {
            showError = true
            code = ""
        }
    }
}

// MARK: - 初回設定 / 変更

struct PasscodeSetupView: View {
    var onSave: (String) -> Void
    var onSaved: () -> Void

    @State private var code = ""
    @State private var confirm = ""
    @State private var message: String?
    @FocusState private var focus: Field?

    private enum Field { case code, confirm }

    var body: some View {
        VStack(spacing: 14) {
            LockBadge()

            VStack(spacing: 4) {
                Text("解除用パスコードを設定")
                    .font(.system(size: 15, weight: .semibold))
                Text("集中をパスコードで解除できるようにします")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                SecureField("パスコード(4文字以上)", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .code)
                SecureField("もう一度入力", text: $confirm)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .confirm)
                    .onSubmit(save)
            }

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Button("パスコードを保存", action: save)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(width: 300)
        .background(.regularMaterial)
        .onAppear { focus = .code }
    }

    private func save() {
        guard code.count >= 4 else {
            message = "4文字以上にしてください"
            return
        }
        guard code == confirm else {
            message = "パスコードが一致しません"
            confirm = ""
            focus = .confirm
            return
        }
        onSave(code)
        onSaved()
    }
}
