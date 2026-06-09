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
        present(view, title: "ロック解除")
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
        present(view, title: "パスコードを設定")
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func present<V: View>(_ view: V, title: String) {
        close()
        let hosting = NSHostingController(rootView: view)
        let p = NSPanel(contentViewController: hosting)
        p.styleMask = [.titled, .closable]
        p.title = title
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        // フルスクリーンアプリの上(同じスペース)に出すための設定。
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.center()
        panel = p

        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 解除入力

struct PasscodeEntryView: View {
    /// 入力されたパスコードが正しければ true。
    var onSubmit: (String) -> Bool
    var onAccepted: () -> Void
    var onCancel: () -> Void

    @State private var code = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text("パスコードで解除")
                .font(.headline)

            SecureField("パスコード", text: $code)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)

            if showError {
                Text("パスコードが違います")
                    .font(.caption)
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
        .padding(20)
        .frame(width: 260)
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

// MARK: - 初回設定

struct PasscodeSetupView: View {
    var onSave: (String) -> Void
    var onSaved: () -> Void

    @State private var code = ""
    @State private var confirm = ""
    @State private var message: String?
    @FocusState private var focus: Field?

    private enum Field { case code, confirm }

    var body: some View {
        VStack(spacing: 12) {
            Text("解除用パスコードを設定")
                .font(.headline)
            Text("集中をパスコードで解除できるようにします")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("パスコード(4文字以上)", text: $code)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: .code)

            SecureField("もう一度入力", text: $confirm)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: .confirm)
                .onSubmit(save)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("設定して始める", action: save)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 280)
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
