import Foundation
import Observation
import Supabase

struct PhucTvSupabaseUserSummary: Equatable, Sendable {
    let id: UUID
    let email: String?
    let displayName: String?

    var title: String {
        if let displayName {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let email {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return "Signed in"
    }
}

@Observable
final class PhucTvSupabaseAuthManager: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(PhucTvSupabaseUserSummary)
        case unavailable(String)
        case error(String)
    }

    @ObservationIgnored
    private let client: SupabaseClient?
    @ObservationIgnored
    private let redirectURL: URL?
    @ObservationIgnored
    private let legacyDataMigrator: PhucTvLegacyLocalDataMigrating?
    @ObservationIgnored
    private var authObserverTask: Task<Void, Never>?

    var state: State = .loading

    init(
        client: SupabaseClient?,
        redirectURL: URL? = nil,
        legacyDataMigrator: PhucTvLegacyLocalDataMigrating? = nil
    ) {
        self.client = client
        self.redirectURL = redirectURL
        self.legacyDataMigrator = legacyDataMigrator
        if client == nil {
            state = .signedOut
            return
        }
        observeAuthState()
        Task { await refreshSessionState() }
    }

    deinit {
        authObserverTask?.cancel()
    }

    var isAuthenticated: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var userSummary: PhucTvSupabaseUserSummary? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    var signInHint: String? {
        switch state {
        case .signedOut:
            return "Đăng nhập để đồng bộ liked movies và playback position."
        case .unavailable(let message), .error(let message):
            return message
        default:
            return nil
        }
    }

    func refreshSessionState() async {
        guard let client else { return }
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.apply(session: session)
            }
        } catch {
            await MainActor.run {
                self.state = .signedOut
            }
        }
    }

    /// Sends a 6-digit OTP to the given email address.
    /// Requires "Email OTP" to be enabled in the Supabase dashboard.
    func sendOTP(email: String) async throws {
        let client = try requireClient()
        try await client.auth.signInWithOTP(email: email)
    }

    /// Verifies the 6-digit OTP entered by the user.
    /// On success, `authStateChanges` fires and updates `state` to `.signedIn`.
    func verifyOTP(email: String, token: String) async throws {
        let client = try requireClient()
        try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
    }

    func signOut() async {
        guard let client else {
            await MainActor.run {
                self.state = .signedOut
            }
            return
        }
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.state = .signedOut
            }
        } catch {
            await MainActor.run {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    nonisolated func handle(_ url: URL) {
        guard let client else { return }
        Task {
            do {
                _ = try await client.auth.session(from: url)
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                    PhucTvLogger.shared.error(error, message: "Failed to handle auth URL: \(url)")
                }
            }
        }
    }

    private func observeAuthState() {
        guard let client else { return }
        authObserverTask = Task {
            for await (_, session) in client.auth.authStateChanges {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.apply(session: session)
                }
            }
        }
    }

    private func apply(session: Session?) {
        guard let session, !session.isExpired else {
            state = .signedOut
            return
        }

        state = .signedIn(makeSummary(from: session.user))
        Task { await legacyDataMigrator?.migrateIfNeeded() }
    }

    private func makeSummary(from user: User) -> PhucTvSupabaseUserSummary {
        PhucTvSupabaseUserSummary(
            id: user.id,
            email: user.email,
            displayName: nil
        )
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            throw PhucTvSupabaseAuthError.missingConfiguration
        }
        return client
    }
}

private enum PhucTvSupabaseAuthError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase is not configured."
        }
    }
}
