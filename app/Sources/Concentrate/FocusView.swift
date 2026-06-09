import SwiftUI
import AppKit

/// ポップオーバーの中身。状態に応じて「時間選択」と「集中中」を切り替える。
struct FocusView: View {
    @ObservedObject var session: SessionController
    @State private var customMinutes = 25

    var body: some View {
        Group {
            switch session.state {
            case .idle:
                idleView
            case .locked:
                lockedView
            }
        }
        .padding(16)
        .frame(width: 250)
    }

    // MARK: - 待機中(時間選択)

    private var idleView: some View {
        VStack(spacing: 12) {
            Text("集中する時間")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach([15, 25, 50], id: \.self) { m in
                    Button("\(m)分") { session.start(minutes: m) }
                        .buttonStyle(.bordered)
                        .disabled(!session.canStart)
                }
            }

            Divider()

            Stepper("カスタム: \(customMinutes)分",
                    value: $customMinutes, in: 1...240, step: 1)
                .font(.callout)

            Button("\(customMinutes)分で集中開始") {
                session.start(minutes: customMinutes)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canStart)

            if !session.permissionGranted {
                Divider()
                Text("⚠️ アクセシビリティ権限が必要です")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("権限を許可する") { session.requestPermission() }
                    .controlSize(.small)
            }

            if !session.passcodeSet {
                Divider()
                Text("⚠️ 解除用パスコードが未設定です")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("パスコードを設定") { session.requestSetup() }
                    .controlSize(.small)
            }

            Divider()
            HStack {
                Button("設定…") { session.requestSettings() }
                    .controlSize(.small)
                Spacer()
                Button("終了") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 集中中

    private var lockedView: some View {
        VStack(spacing: 12) {
            Text("集中中")
                .font(.headline)

            Text(session.remainingText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("⌘Tab・スペース切替はロック中")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("パスコードで解除") {
                session.requestUnlock()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Text("ホットキー ⌃⌥⌘P でも解除できます")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
