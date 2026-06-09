import SwiftUI

/// 設定ウィンドウの中身。パスコード変更・挙動・自動起動・連携情報をまとめる。
struct SettingsView: View {
    @ObservedObject var session: SessionController
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("解除パスコード") {
                Button("パスコードを変更…") { session.requestSetup() }
            }

            Section("ロック中の挙動") {
                Toggle("別スペースへ移動したら引き戻す", isOn: $session.bounceBackEnabled)
            }

            Section("起動") {
                Toggle("ログイン時に自動起動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItem.setEnabled(newValue)
                        // 実際の状態を取り込み直す(承認待ちなどで戻ることがある)。
                        launchAtLogin = LoginItem.isEnabled
                    }
                if LoginItem.requiresApproval {
                    Text("システム設定 > 一般 > ログイン項目 で承認が必要です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Raycast / URL スキーム") {
                LabeledContent("ポップアップを開く") {
                    Text("concentrate://open").monospaced().textSelection(.enabled)
                }
                LabeledContent("25分の集中を開始") {
                    Text("concentrate://focus?minutes=25").monospaced().textSelection(.enabled)
                }
            }

            Section("ホットキー") {
                LabeledContent("ロック中の解除", value: "⌃⌥⌘P")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
    }
}
