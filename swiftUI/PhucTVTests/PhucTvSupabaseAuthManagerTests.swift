import Testing

@testable import PhucTV

@MainActor
struct PhucTvSupabaseAuthManagerTests {
    @Test
    func signInHintFallsBackWhileLoading() {
        let authManager = PhucTvSupabaseAuthManager(client: nil)
        authManager.state = .loading

        #expect(
            authManager.signInHint == "Đăng nhập để đồng bộ liked movies và playback position."
        )
    }
}
