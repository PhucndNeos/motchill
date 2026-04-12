//
//  ErrorOverlay.swift
//  MotchillSwiftUI
//
//  Created by Phucnd on 12/4/26.
//  Copyright © 2026 Motchill. All rights reserved.
//

import SwiftUI

struct ErrorOverlay: View {
    enum Icon {
        case generic
        case network
        case server
        case playback
        case loading

        var systemImageName: String {
            switch self {
            case .generic:
                return "exclamationmark.circle.fill"
            case .network:
                return "wifi.slash"
            case .server:
                return "server.rack"
            case .playback:
                return "play.slash"
            case .loading:
                return "arrow.triangle.2.circlepath"
            }
        }

        var glowColor: Color {
            switch self {
            case .generic:
                return Color(red: 0.42, green: 0.04, blue: 0.09)
            case .network:
                return Color(red: 0.42, green: 0.04, blue: 0.09)
            case .server:
                return Color(red: 0.18, green: 0.09, blue: 0.32)
            case .playback:
                return Color(red: 0.30, green: 0.02, blue: 0.11)
            case .loading:
                return Color(red: 0.16, green: 0.15, blue: 0.20)
            }
        }

        var symbolColor: Color {
            switch self {
            case .loading:
                return Color(red: 0.90, green: 0.88, blue: 0.86)
            default:
                return Color(red: 0.97, green: 0.84, blue: 0.82)
            }
        }

        var ringColor: Color {
            switch self {
            case .loading:
                return Color.white.opacity(0.12)
            default:
                return Color.red.opacity(0.10)
            }
        }
    }

    let title: String
    let message: String
    let retryTitle: String
    let homeTitle: String
    let errorCode: String?
    let icon: Icon
    let isLoading: Bool
    let onRetry: () -> Void
    let onGoHome: (() -> Void)?

    @State private var loadingRotation: Double = 0

    init(
        title: String = "Something Went Wrong",
        message: String,
        retryTitle: String = "Retry",
        homeTitle: String = "Go back to Home",
        errorCode: String? = nil,
        icon: Icon = .network,
        isLoading: Bool = false,
        onRetry: @escaping () -> Void,
        onGoHome: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.homeTitle = homeTitle
        self.errorCode = errorCode
        self.icon = icon
        self.isLoading = isLoading
        self.onRetry = onRetry
        self.onGoHome = onGoHome
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                content
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()
        }
    }

    private var background: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color(red: 0.28, green: 0.05, blue: 0.08).opacity(0.52),
                    Color.black.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            .blur(radius: 22)
            .scaleEffect(1.1)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 96, height: 96)
                    .blur(radius: 18)
                    .offset(x: -176, y: -240)
            }
            .opacity(0.65)

            VStack {
                Spacer()
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 96, height: 96)
                    .blur(radius: 18)
                    .offset(x: 170, y: -240)
            }
            .opacity(0.65)

            NoiseTexture()
                .blendMode(.overlay)
                .opacity(0.05)
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            brand

            iconCluster

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(message)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
            }

            actionRow

            if let errorCode {
                metadata(errorCode: errorCode)
            }
        }
        .padding(.vertical, 28)
    }

    private var brand: some View {
        Text("MOTCHILL")
            .font(.system(size: 22, weight: .black, design: .rounded))
            .italic()
            .tracking(1.6)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.78, blue: 0.74),
                        Color(red: 0.98, green: 0.19, blue: 0.17)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var iconCluster: some View {
        let resolvedIcon = isLoading ? Icon.loading : icon
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            resolvedIcon.glowColor.opacity(0.82),
                            resolvedIcon.glowColor.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 12)

            Circle()
                .stroke(resolvedIcon.ringColor, lineWidth: 1)
                .frame(width: 132, height: 132)
                .blur(radius: 0.5)

            Image(systemName: resolvedIcon.systemImageName)
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .foregroundStyle(resolvedIcon.symbolColor)
                .shadow(color: resolvedIcon.glowColor.opacity(0.22), radius: 14, x: 0, y: 8)
                .padding(10)
                .rotationEffect(.degrees(isLoading ? loadingRotation : 0))
        }
        .frame(height: 164)
        .onAppear {
            guard isLoading else { return }
            loadingRotation = 0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
        }
        .onChange(of: isLoading) { _, newValue in
            guard newValue else {
                loadingRotation = 0
                return
            }

            loadingRotation = 0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 14) {
            Button(action: onRetry) {
                ZStack {
                    Text(retryTitle.uppercased())
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .tracking(2.1)
                        .opacity(isLoading ? 0 : 1)

                    if isLoading {
                        ProgressView()
                            .tint(Color(red: 0.36, green: 0.02, blue: 0.03))
                    }
                }
                .foregroundStyle(Color(red: 0.36, green: 0.02, blue: 0.03))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.80, blue: 0.78),
                            Color(red: 1.0, green: 0.20, blue: 0.18)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: Color(red: 0.90, green: 0.16, blue: 0.16).opacity(0.34),
                    radius: 24,
                    x: 0,
                    y: 12
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            if let onGoHome {
                Button(action: onGoHome) {
                    Text(homeTitle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 300)
    }

    private func metadata(errorCode: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Error Code: \(errorCode)")
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .tracking(2.0)
        .foregroundStyle(AppTheme.textMuted)
        .padding(.top, 16)
    }
}

private struct NoiseTexture: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 28
            let columns = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))

            for row in 0..<rows {
                for column in 0..<columns {
                    let x = CGFloat(column) * cellSize
                    let y = CGFloat(row) * cellSize
                    let opacity = Double(((column * 13 + row * 17) % 7) + 1) / 100

                    let rect = CGRect(
                        x: x,
                        y: y,
                        width: cellSize,
                        height: cellSize
                    )

                    context.fill(
                        Path(rect),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

#Preview("Error Overlay") {
    ErrorOverlay(
        message: "We encountered an error while loading the content. Please check your internet connection and try again.",
        errorCode: "MOT_502_STREAM",
        icon: .network,
        isLoading: true,
        onRetry: {}
    )
}
