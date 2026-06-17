import SwiftUI
import AppKit

/// ポップオーバーの中身。待機(時間選択)と集中中(リング)を切り替える。
struct FocusView: View {
    @ObservedObject var session: SessionController
    /// -1 はカスタム。
    @State private var selection = 25
    @State private var customMinutes = 30

    private var chosenMinutes: Int { selection == -1 ? customMinutes : selection }

    var body: some View {
        Group {
            switch session.state {
            case .idle:   idleView
            case .locked: lockedView
            }
        }
        .padding(Theme.contentPadding)
        .frame(width: Theme.popoverWidth)
        .tint(Theme.accent)
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.accentGradient)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text("Concentrate")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                session.requestSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 待機(時間選択)

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            SectionLabel("集中する時間")

            Picker("", selection: $selection) {
                Text("25").tag(25)
                Text("45").tag(45)
                Text("60").tag(60)
                Text("90").tag(90)
                Text("カスタム").tag(-1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if selection == -1 {
                Stepper("\(customMinutes) 分", value: $customMinutes, in: 1...240)
                    .font(.system(size: 12))
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("開始するとアプリの切り替えとスペース移動をブロックします。")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            if !session.permissionGranted {
                warning("アクセシビリティ権限が必要です", action: "許可") {
                    session.requestPermission()
                }
            }
            if !session.passcodeSet {
                warning("解除用パスコードが未設定です", action: "設定") {
                    session.requestSetup()
                }
            }

            Button {
                session.start(minutes: chosenMinutes)
            } label: {
                Text("集中を開始")
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(!session.canStart)

            Text("時間経過、または ⌃⌥⌘P で解除")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func warning(_ message: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action, action: perform)
                .controlSize(.small)
        }
    }

    // MARK: - 集中中

    private var lockedView: some View {
        VStack(spacing: 14) {
            Text("集中中")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)

            CountdownRing(progress: session.progress, timeText: session.remainingText)
                .padding(.vertical, 2)

            if let name = session.targetApp?.localizedName {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text("\(name) をロック中")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                session.requestUnlock()
            } label: {
                Text("パスコードで解除")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            VStack(spacing: 3) {
                Text("解除するには ⌃⌥⌘P")
                Text("⌘⌥Esc(強制終了)は安全のため常に有効です")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
    }
}
