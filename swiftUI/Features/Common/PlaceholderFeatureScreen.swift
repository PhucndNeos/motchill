import SwiftUI

struct PlaceholderFeatureScreen: View {
    let title: String
    let subtitle: String
    let description: String
    let backTitle: String
    let systemImage: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.11),
                    Color(red: 0.11, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header

                Button(action: onBack) {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.left")
                        Text(backTitle)
                            .fontWeight(.semibold)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.78, blue: 0.73))
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.73))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.white.opacity(0.08))
                )

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.84))

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
