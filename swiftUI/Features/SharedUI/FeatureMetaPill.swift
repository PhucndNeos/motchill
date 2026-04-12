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
                text: Color(red: 0.88, green: 0.84, blue: 1.0),
                background: Color(red: 0.35, green: 0.27, blue: 0.62).opacity(0.32),
                border: Color(red: 0.55, green: 0.44, blue: 0.84).opacity(0.45)
            )
        case .rating:
            return FeatureMetaPillStyle(
                text: Color(red: 1.0, green: 0.90, blue: 0.74),
                background: Color(red: 0.52, green: 0.33, blue: 0.08).opacity(0.34),
                border: Color(red: 0.86, green: 0.62, blue: 0.21).opacity(0.48)
            )
        case .quality:
            return FeatureMetaPillStyle(
                text: Color(red: 0.79, green: 0.93, blue: 1.0),
                background: Color(red: 0.09, green: 0.35, blue: 0.48).opacity(0.34),
                border: Color(red: 0.38, green: 0.73, blue: 0.92).opacity(0.44)
            )
        case .status:
            return FeatureMetaPillStyle(
                text: Color(red: 0.80, green: 0.98, blue: 0.84),
                background: Color(red: 0.10, green: 0.40, blue: 0.19).opacity(0.36),
                border: Color(red: 0.36, green: 0.76, blue: 0.47).opacity(0.46)
            )
        case .views:
            return FeatureMetaPillStyle(
                text: Color(red: 1.0, green: 0.83, blue: 0.89),
                background: Color(red: 0.50, green: 0.13, blue: 0.27).opacity(0.34),
                border: Color(red: 0.83, green: 0.36, blue: 0.55).opacity(0.44)
            )
        case .episodes:
            return FeatureMetaPillStyle(
                text: Color(red: 0.80, green: 0.90, blue: 1.0),
                background: Color(red: 0.12, green: 0.28, blue: 0.50).opacity(0.34),
                border: Color(red: 0.34, green: 0.57, blue: 0.93).opacity(0.46)
            )
        case .duration:
            return FeatureMetaPillStyle(
                text: Color(red: 0.98, green: 0.89, blue: 0.78),
                background: Color(red: 0.47, green: 0.27, blue: 0.13).opacity(0.34),
                border: Color(red: 0.79, green: 0.50, blue: 0.27).opacity(0.44)
            )
        case .generic:
            return FeatureMetaPillStyle(
                text: AppTheme.textPrimary,
                background: Color.white.opacity(0.05),
                border: Color.white.opacity(0.10)
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

        if lower.contains("eps") || lower.contains("ep ") {
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
