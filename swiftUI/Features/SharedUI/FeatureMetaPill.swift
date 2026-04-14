import SwiftUI

struct FeatureMetaPill: View {
    let text: String

    private var style: FeatureMetaPillStyle {
        FeatureMetaPillStyle.forText(text)
    }

    var body: some View {
        Text(text)
            .font(AppTheme.captionFont.weight(.semibold))
            .foregroundStyle(style.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(style.background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
    }
}

private struct FeatureMetaPillStyle {
    let text: Color
    let background: Color
    let border: Color

    static func forText(_ text: String) -> FeatureMetaPillStyle {
        switch classify(text) {
        case .year:
            return FeatureMetaPillStyle(
                text: Color.white,
                background: Color(hex: 0x9B5DE5).opacity(0.88),
                border: Color.white.opacity(0.26)
            )
        case .rating:
            return FeatureMetaPillStyle(
                text: Color.black.opacity(0.82),
                background: Color(hex: 0xFEE440).opacity(0.94),
                border: Color.white.opacity(0.28)
            )
        case .quality:
            return FeatureMetaPillStyle(
                text: Color.black.opacity(0.84),
                background: Color(hex: 0x00F5D4).opacity(0.90),
                border: Color.white.opacity(0.28)
            )
        case .status:
            return FeatureMetaPillStyle(
                text: Color.white,
                background: Color(hex: 0xD61C4E).opacity(0.88),
                border: Color.white.opacity(0.24)
            )
        case .views:
            return FeatureMetaPillStyle(
                text: Color.white,
                background: Color(hex: 0xF15BB5).opacity(0.88),
                border: Color.white.opacity(0.24)
            )
        case .episodes:
            return FeatureMetaPillStyle(
                text: Color.white,
                background: Color(hex: 0x00BBF9).opacity(0.90),
                border: Color.white.opacity(0.26)
            )
        case .duration:
            return FeatureMetaPillStyle(
                text: Color.white,
                background: Color(hex: 0xF77E21).opacity(0.90),
                border: Color.white.opacity(0.24)
            )
        case .generic:
            return FeatureMetaPillStyle(
                text: AppTheme.textPrimary,
                background: Color.black.opacity(0.52),
                border: Color.white.opacity(0.22)
            )
        }
    }

    private static func classify(_ text: String) -> FeatureMetaPillKind {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .generic }

        let lower = value.lowercased()

        if value.range(of: #"^\d{4}$"#, options: .regularExpression) != nil {
            return .year
        }

        if value.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil {
            return .rating
        }

        if lower.contains("4k") || lower.contains("fhd") || lower.contains("hd") || lower.contains("cam") {
            return .quality
        }

        if lower.contains("ongoing") || lower.contains("completed") || lower.contains("full") || lower.contains("updating") || lower.contains("status") || lower.contains("sẵn sàng") {
            return .status
        }

        if lower.contains("eps") || lower.contains("ep ") || lower.contains("tập") {
            return .episodes
        }

        if lower.contains("tm.") || lower.contains("min") || lower.contains("phút") || value.contains(":") {
            return .duration
        }

        if lower.range(of: #"\d+(\.\d+)?[km]$"#, options: .regularExpression) != nil {
            return .views
        }

        return .generic
    }
}

private enum FeatureMetaPillKind {
    case year
    case rating
    case quality
    case status
    case views
    case episodes
    case duration
    case generic
}

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
