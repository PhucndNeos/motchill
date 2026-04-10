import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let card = Color(red: 0.13, green: 0.15, blue: 0.21)
    static let border = Color.white.opacity(0.10)
    static let borderSoft = Color.white.opacity(0.06)
    static let accent = Color(red: 0.30, green: 0.02, blue: 0.11)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.76)
    static let textMuted = Color.white.opacity(0.54)

    static let titleFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let sectionTitleFont = Font.system(.title3, design: .rounded).weight(.semibold)
    static let cardTitleFont = Font.system(.headline, design: .rounded).weight(.semibold)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
}
