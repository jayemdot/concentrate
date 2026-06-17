import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// デザイントークン。アクセントは system indigo を基調に、リング等はグラデを明示。
enum Theme {
    static let accent = Color.indigo
    static let accentLight = Color(hex: 0x7D7BFF)
    static let accentDark = Color(hex: 0x4A48C4)
    static let ringStart = Color(hex: 0x5E5CE6)
    static let ringEnd = Color(hex: 0x8B89FF)

    static let accentGradient = LinearGradient(
        colors: [accentLight, accentDark],
        startPoint: .top, endPoint: .bottom
    )
    static let ringGradient = LinearGradient(
        colors: [ringStart, ringEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let popoverWidth: CGFloat = 288
    static let contentPadding: CGFloat = 16
    static let corner: CGFloat = 8
}

/// 全幅・indigo グラデ・白文字の主役ボタン。
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GradientButtonLabel(configuration: configuration)
    }

    struct GradientButtonLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .fill(Theme.accentGradient)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .contentShape(Rectangle())
        }
    }
}

/// 大文字・トラッキングのセクションラベル。
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
