import SwiftUI

/// 集中中の主役。残り時間を弧で表すカウントダウンリング。
struct CountdownRing: View {
    /// 残りの割合(1=満タン, 0=終了)。
    var progress: Double
    var timeText: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private let diameter: CGFloat = 188
    private let lineWidth: CGFloat = 12

    private var animationsAllowed: Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Theme.ringGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(animationsAllowed ? 0.5 : 0), radius: 8)
                .animation(.linear(duration: 0.45), value: progress)

            VStack(spacing: 2) {
                Text(timeText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("残り")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(breathing ? 1.012 : 1.0)
        .animation(animationsAllowed
                   ? .easeInOut(duration: 4).repeatForever(autoreverses: true)
                   : .default,
                   value: breathing)
        .onAppear { if animationsAllowed { breathing = true } }
        .accessibilityElement()
        .accessibilityLabel("残り \(timeText)")
    }
}
