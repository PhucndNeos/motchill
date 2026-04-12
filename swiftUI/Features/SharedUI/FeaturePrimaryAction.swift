import SwiftUI

struct FeaturePrimaryAction: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))

            Text(text)
                .font(.system(size: 19, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color(red: 0.25, green: 0.02, blue: 0.03))
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.76, blue: 0.73),
                    Color(red: 0.95, green: 0.15, blue: 0.16)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.20), radius: 24, x: 0, y: 12)
    }
}
