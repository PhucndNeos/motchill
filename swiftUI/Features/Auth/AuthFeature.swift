import ComposableArchitecture
import Foundation

@Reducer
struct AuthFeature {
    enum CancelID {
        case resendCooldown
        case requestOTP
        case verifyOTP
    }

    @ObservableState
    struct State: Equatable {
        var email = ""
        var otpCode = ""
        var step: AuthStep = .emailEntry
        var isBusy = false
        var feedbackMessage: FeedbackMessage?
        var resendCooldown = 0

        var canSubmitEmail: Bool {
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var canSubmitOTP: Bool {
            otpCode.count >= 6
        }

        var resendButtonTitle: String {
            resendCooldown > 0 ? "Gửi lại (\(resendCooldown)s)" : "Gửi lại mã"
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case sendOTPButtonTapped
        case resendOTPButtonTapped
        case verifyOTPButtonTapped
        case changeEmailButtonTapped
        case closeButtonTapped
        case requestOTPResponse(RequestOTPResult, isResend: Bool)
        case verifyOTPResponse(VerifyOTPResult)
        case cooldownTick
        case delegate(Delegate)

        enum Delegate: Equatable {
            case closeRequested
            case authenticated
        }
    }

    struct FeedbackMessage: Equatable {
        let text: String
        let isError: Bool
    }

    enum RequestOTPResult: Equatable {
        case success(String)
        case failure(String)
    }

    enum VerifyOTPResult: Equatable {
        case success
        case failure(String)
    }

    enum AuthStep: Equatable {
        case emailEntry
        case otpEntry(email: String)
    }

    @Dependency(\.phucTvAuthManager) private var authManager
    @Dependency(\.continuousClock) private var clock

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.email):
                return .none

            case .binding(\.otpCode):
                let filtered = state.otpCode.filter(\.isNumber)
                state.otpCode = String(filtered)
                return .none

            case .sendOTPButtonTapped:
                return requestOTP(email: state.email, state: &state, isResend: false)

            case .resendOTPButtonTapped:
                guard case let .otpEntry(email) = state.step else {
                    return .none
                }
                return requestOTP(email: email, state: &state, isResend: true)

            case .verifyOTPButtonTapped:
                guard case let .otpEntry(email) = state.step, state.canSubmitOTP, !state.isBusy else {
                    return .none
                }
                state.isBusy = true
                state.feedbackMessage = nil
                let otpCode = state.otpCode
                return .run { send in
                    do {
                        try await authManager.verifyOTP(email, otpCode)
                        await authManager.refreshSessionState()
                        await send(.verifyOTPResponse(.success))
                    } catch is CancellationError {
                    } catch {
                        await send(.verifyOTPResponse(.failure(error.localizedDescription)))
                    }
                }
                .cancellable(id: CancelID.verifyOTP, cancelInFlight: true)

            case .changeEmailButtonTapped:
                state.step = .emailEntry
                state.otpCode = ""
                state.feedbackMessage = nil
                state.resendCooldown = 0
                return .cancel(id: CancelID.resendCooldown)

            case .closeButtonTapped:
                return .send(.delegate(.closeRequested))

            case let .requestOTPResponse(.success(email), isResend):
                state.isBusy = false
                state.step = .otpEntry(email: email)
                state.resendCooldown = 60
                state.feedbackMessage = isResend
                    ? .init(text: "Đã gửi lại mã OTP.", isError: false)
                    : nil
                return startCooldown()

            case let .requestOTPResponse(.failure(message), _):
                state.isBusy = false
                state.feedbackMessage = .init(text: message, isError: true)
                return .none

            case .verifyOTPResponse(.success):
                state.isBusy = false
                return .send(.delegate(.authenticated))

            case let .verifyOTPResponse(.failure(message)):
                state.isBusy = false
                state.feedbackMessage = .init(text: message, isError: true)
                return .none

            case .cooldownTick:
                if state.resendCooldown > 0 {
                    state.resendCooldown -= 1
                }
                if state.resendCooldown == 0 {
                    return .cancel(id: CancelID.resendCooldown)
                }
                return .none

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }

    private func requestOTP(
        email: String,
        state: inout State,
        isResend: Bool
    ) -> Effect<Action> {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !state.isBusy else {
            return .none
        }

        state.isBusy = true
        state.feedbackMessage = nil

        return .run { send in
            do {
                try await authManager.sendOTP(trimmedEmail)
                await send(.requestOTPResponse(.success(trimmedEmail), isResend: isResend))
            } catch is CancellationError {
            } catch {
                await send(.requestOTPResponse(.failure(error.localizedDescription), isResend: isResend))
            }
        }
        .cancellable(id: CancelID.requestOTP, cancelInFlight: true)
    }

    private func startCooldown() -> Effect<Action> {
        .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.cooldownTick)
            }
        }
        .cancellable(id: CancelID.resendCooldown, cancelInFlight: true)
    }
}
