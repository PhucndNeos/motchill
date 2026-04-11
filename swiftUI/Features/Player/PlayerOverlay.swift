//
//  PlayerOverlay.swift
//  MotchillSwiftUI
//
//  Created by Phucnd on 11/4/26.
//  Copyright © 2026 Motchill. All rights reserved.
//

import SwiftUI

struct PlayerOverlay: View {
    @Bindable var viewModel: PlayerViewModel
    let onBack: () -> Void

    init(
        viewModel: PlayerViewModel,
        onBack: @escaping () -> Void
    ) {
        self._viewModel = Bindable(viewModel)
        self.onBack = onBack
    }

    private var selectedSourceBinding: Binding<MotchillPlaySource?> {
        Binding(
            get: { viewModel.selectedSource },
            set: { newValue in
                guard let newValue else { return }
                if let index = viewModel.playableSources.firstIndex(where: { $0.id == newValue.id }) {
                    viewModel.selectSource(index)
                }
            }
        )
    }

    private var progressBufferFraction: Double {
        min(viewModel.progressFraction + 0.23, 1)
    }

    private var playIcon: String {
        viewModel.isPlaying ? "pause.fill" : "play.fill"
    }

    private var audioLabel: String {
        viewModel.selectedAudioTrack?.displayLabel ?? "AUDIO"
    }

    private var subtitleLabel: String {
        viewModel.selectedSubtitleTrack?.displayLabel ?? "SUBS"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                playerOverlayScrim

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 48)
                        .padding(.top, 28)

                    Spacer(minLength: 0)

                    centerControls

                    Spacer(minLength: 0)

                    bottomPanel
                        .padding(.horizontal, 48)
                        .padding(.bottom, 28)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                sidePanel
                    .padding(.trailing, 48)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }

    private var playerOverlayScrim: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.74)
                ],
                center: .center,
                startRadius: 160,
                endRadius: 900
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    .clear,
                    .clear,
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 16) {
            PlayerOverlayIconButton(
                icon: "chevron.left",
                size: 20,
                backgroundOpacity: 0.20,
                onTap: onBack
            )

            Spacer(minLength: 16)

            VStack(spacing: 4) {
                Text(viewModel.movieTitle)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.76, blue: 0.73))
                    .tracking(-0.6)
                    .lineLimit(1)

                Text("\(viewModel.episodeLabel) • \(viewModel.sourceTitle)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
                    .tracking(2.4)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 16)

            HStack(spacing: 16) {
                PlayerOverlayIconButton(
                    icon: "airplayaudio",
                    size: 18,
                    backgroundOpacity: 0.12,
                    onTap: {}
                )

                PlayerOverlayIconButton(
                    icon: "gearshape.fill",
                    size: 18,
                    backgroundOpacity: 0.12,
                    onTap: {}
                )
            }
        }
    }

    private var centerControls: some View {
        HStack(spacing: 26) {
            PlayerOverlayControlButton(
                icon: "goforward.10",
                size: 18,
                onTap: {
                    viewModel.seek(by: -viewModel.seekStepMillis)
                }
            )

            Button(action: {
                viewModel.togglePlayback()
            }) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.78, blue: 0.76),
                            Color(red: 0.96, green: 0.16, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: playIcon)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(Color(red: 0.38, green: 0.01, blue: 0.01))
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.34), radius: 42, x: 0, y: 18)
            }
            .buttonStyle(.plain)

            PlayerOverlayControlButton(
                icon: "goforward.10",
                size: 18,
                flipped: true,
                onTap: {
                    viewModel.seek(by: viewModel.seekStepMillis)
                }
            )
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))

                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: proxy.size.width * progressBufferFraction)

                        Capsule(style: .continuous)
                            .fill(Color(red: 1.0, green: 0.78, blue: 0.76))
                            .shadow(color: Color(red: 1.0, green: 0.76, blue: 0.73).opacity(0.45), radius: 10, x: 0, y: 0)
                            .frame(width: proxy.size.width * viewModel.progressFraction)
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule(style: .continuous))
                .contentShape(Rectangle())

                HStack {
                    Text(formatMillis(viewModel.currentPositionMillis))
                    Spacer()
                    Text(formatMillis(viewModel.durationMillis))
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text("Select Source")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted.opacity(0.65))
                        .tracking(2.6)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }

                if !viewModel.playableSources.isEmpty {
                    TabSegmentedView(
                        selectedItem: selectedSourceBinding,
                        items: viewModel.playableSources,
                        spacing: 12,
                        horizontalPadding: 0
                    ) { source, isSelected in
                        Text(source.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? Color(red: 0.95, green: 0.78, blue: 0.77) : AppTheme.textPrimary.opacity(0.72))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color(red: 0.95, green: 0.16, blue: 0.18).opacity(0.14) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isSelected ? Color(red: 1.0, green: 0.67, blue: 0.64) : Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .shadow(
                                color: isSelected ? Color(red: 0.92, green: 0.22, blue: 0.26).opacity(0.12) : .clear,
                                radius: 14,
                                x: 0,
                                y: 6
                            )
                    }
                }
            }
        }
    }

    private var sidePanel: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(spacing: 28) {
                PlayerOverlaySideButton(
                    icon: "speaker.wave.2.fill",
                    label: audioLabel,
                    onTap: {
                        viewModel.showOverlayTemporarily()
                    }
                )

                PlayerOverlaySideButton(
                    icon: "captions.bubble.fill",
                    label: subtitleLabel,
                    onTap: {
                        viewModel.showOverlayTemporarily()
                    }
                )

                PlayerOverlaySideButton(
                    icon: "speedometer",
                    label: "1.0X",
                    onTap: {
                        viewModel.showOverlayTemporarily()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct PlayerOverlayIconButton: View {
    let icon: String
    let size: CGFloat
    let backgroundOpacity: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.white.opacity(backgroundOpacity))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerOverlayControlButton: View {
    let icon: String
    let size: CGFloat
    var flipped: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.88))
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .scaleEffect(x: flipped ? -1 : 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerOverlaySideButton: View {
    let icon: String
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(width: 56, height: 56)

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted.opacity(0.55))
                    .tracking(1.6)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private func formatMillis(_ value: Int64) -> String {
    let totalSeconds = max(Int(value / 1000), 0)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

#Preview("Player Overlay") {
    PlayerOverlay(
        viewModel: PlayerViewModel.previewLoaded(),
        onBack: {}
    )
    .preferredColorScheme(.dark)
}
