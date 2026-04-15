import Observation
import SwiftUI

struct AuthView: View {
    @Bindable var authManager: PhucTvSupabaseAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var otpCode = ""
    @State private var step: AuthStep = .emailEntry
    @State private var isBusy = false
    @State private var feedbackMessage: FeedbackMessage?
    @State private var resendCooldown = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        brandHeader
                        authCard
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
        .task(id: step) {
            // Start 60s cooldown the moment OTP step is entered.
            guard case .otpEntry = step else { return }
            resendCooldown = 60
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard case .otpEntry = step else { return }
                resendCooldown -= 1
            }
        }
    }

    // MARK: - Header

    private var brandHeader: some View {
        VStack(spacing: 10) {
            Text("PHUCTV")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2)

            Text("Welcome Back")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(headerSubtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .animation(.easeInOut(duration: 0.2), value: step)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var headerSubtitle: String {
        switch step {
        case .emailEntry:
            return "Nhập email để nhận mã OTP. Không cần mật khẩu."
        case .otpEntry:
            return "Kiểm tra email và nhập mã 6 chữ số."
        }
    }

    // MARK: - Card

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch step {
            case .emailEntry:
                emailField
                sendOTPButton
                footerNote
            case .otpEntry(let sentEmail):
                otpSentBanner(email: sentEmail)
                otpField
                verifyButton
                changeEmailButton
            }
        }
        .padding(22)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 34, x: 0, y: 24)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Email step

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EMAIL ADDRESS")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 18)

                TextField("name@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .submitLabel(.done)
                    .onSubmit { Task { await sendOTP() } }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var sendOTPButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await sendOTP() }
            } label: {
                HStack(spacing: 10) {
                    if isBusy {
                        ProgressView().tint(.black)
                    }
                    Text("Nhận mã OTP")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.78, blue: 0.73), Color(red: 1.0, green: 0.15, blue: 0.16)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .shadow(color: Color.red.opacity(0.25), radius: 18, x: 0, y: 10)
            .disabled(isBusy || !canSubmitEmail)

            feedbackRow
        }
        .padding(.top, 2)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cách hoạt động")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text("1. Nhập email")
            Text("2. Nhận mã OTP 6 chữ số")
            Text("3. Nhập mã để đăng nhập ngay")
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.58))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    // MARK: - OTP step

    private func otpSentBanner(email: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.55))
                .font(.subheadline)
            Text("Mã OTP đã gửi đến **\(email)**")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.35), lineWidth: 1)
        )
    }

    private var otpField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MÃ OTP")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 18)

                TextField("000000", text: $otpCode)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .tracking(8)
                    .onChange(of: otpCode) { _, newValue in
                        // Allow digits only, max 6 chars
                        let filtered = newValue.filter(\.isNumber)
                        let trimmed = String(filtered.prefix(6))
                        if trimmed != newValue { otpCode = trimmed }
                        // Auto-submit on 6 digits
                        if trimmed.count == 6 { Task { await verifyOTP() } }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        otpCode.count == 6
                            ? Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.7)
                            : Color.white.opacity(0.12),
                        lineWidth: otpCode.count == 6 ? 1.5 : 1
                    )
            )
        }
    }

    private var verifyButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await verifyOTP() }
            } label: {
                HStack(spacing: 10) {
                    if isBusy {
                        ProgressView().tint(.black)
                    }
                    Text("Xác nhận & Đăng nhập")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.78, blue: 0.73), Color(red: 1.0, green: 0.15, blue: 0.16)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .shadow(color: Color.red.opacity(0.25), radius: 18, x: 0, y: 10)
            .disabled(isBusy || !canSubmitOTP)

            feedbackRow
        }
        .padding(.top, 2)
    }

    private var changeEmailButton: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation {
                    step = .emailEntry
                    otpCode = ""
                    feedbackMessage = nil
                }
            } label: {
                Text("Đổi email")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .underline()
            }
            .buttonStyle(.plain)

            Text(" · ")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.3))

            Button {
                Task { await resendOTP() }
            } label: {
                Group {
                    if resendCooldown > 0 {
                        Text("Gửi lại (\(resendCooldown)s)")
                    } else {
                        Text("Gửi lại mã")
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(resendCooldown > 0 ? .white.opacity(0.28) : .white.opacity(0.55))
                .underline(resendCooldown == 0)
            }
            .buttonStyle(.plain)
            .disabled(isBusy || resendCooldown > 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared

    @ViewBuilder
    private var feedbackRow: some View {
        if let msg = feedbackMessage {
            HStack(spacing: 8) {
                Image(systemName: msg.isError ? "exclamationmark.circle" : "info.circle")
                    .font(.footnote)
                    .foregroundStyle(msg.isError ? Color.red.opacity(0.85) : Color.white.opacity(0.65))
                Text(msg.text)
                    .font(.footnote)
                    .foregroundStyle(msg.isError ? Color.red.opacity(0.85) : Color.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Validation

    private var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmitOTP: Bool {
        otpCode.count == 6
    }

    // MARK: - Actions

    private func sendOTP() async {
        guard canSubmitEmail else { return }
        isBusy = true
        feedbackMessage = nil
        defer { isBusy = false }

        do {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            try await authManager.sendOTP(email: trimmed)
            withAnimation { step = .otpEntry(email: trimmed) }
        } catch {
            feedbackMessage = FeedbackMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func resendOTP() async {
        guard case .otpEntry(let sentEmail) = step else { return }
        isBusy = true
        feedbackMessage = nil
        defer { isBusy = false }

        do {
            try await authManager.sendOTP(email: sentEmail)
            feedbackMessage = FeedbackMessage(text: "Đã gửi lại mã OTP.", isError: false)
            resendCooldown = 60
        } catch {
            feedbackMessage = FeedbackMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func verifyOTP() async {
        guard case .otpEntry(let sentEmail) = step, canSubmitOTP else { return }
        isBusy = true
        feedbackMessage = nil
        defer { isBusy = false }

        do {
            try await authManager.verifyOTP(email: sentEmail, token: otpCode)
            // dismiss() is triggered by .onChange(of: authManager.isAuthenticated)
        } catch {
            feedbackMessage = FeedbackMessage(text: error.localizedDescription, isError: true)
        }
    }
}

// MARK: - Supporting types

private enum AuthStep: Equatable {
    case emailEntry
    case otpEntry(email: String)
}

private struct FeedbackMessage: Equatable {
    let text: String
    let isError: Bool
}

// MARK: - Background & styling

private struct AuthBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.11, green: 0.08, blue: 0.12),
                    Color(red: 0.04, green: 0.06, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.red.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: -150, y: -220)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 180, height: 180)
                .blur(radius: 42)
                .offset(x: 130, y: -160)

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.16),
                            Color.clear,
                            Color.red.opacity(0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 420, height: 560)
                .blur(radius: 46)
                .rotationEffect(.degrees(-18))
                .offset(x: 150, y: 260)
        }
    }
}

private extension Color {
    static let authCardFill = Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92)
}

private var cardBackground: some ShapeStyle {
    LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.authCardFill,
            Color.black.opacity(0.72)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private var cardBorder: some View {
    RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
}
