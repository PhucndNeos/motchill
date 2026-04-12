import Foundation

struct MotchillRemoteConfig: Codable, Equatable {
    let domain: String
    let key: String

    var apiBaseURL: URL? {
        URL(string: domain)
    }

    var isValid: Bool {
        !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && apiBaseURL != nil
    }
}

enum MotchillRemoteConfigError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(code: Int, url: URL)
    case emptyBody
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The remote config response was invalid."
        case let .httpStatus(code, url):
            return "HTTP \(code) for \(url.absoluteString)"
        case .emptyBody:
            return "The remote config body was empty."
        case .invalidPayload:
            return "The remote config payload was invalid."
        }
    }
}

protocol MotchillRemoteConfigStoring: AnyObject, Sendable {
    var current: MotchillRemoteConfig? { get }

    func update(_ config: MotchillRemoteConfig?)
    func reset()
}

final class MotchillRemoteConfigStore: MotchillRemoteConfigStoring, @unchecked Sendable {
    static let shared = MotchillRemoteConfigStore()

    private let lock = NSLock()
    private var storage: MotchillRemoteConfig?

    var current: MotchillRemoteConfig? {
        lock.withLock { storage }
    }

    var apiBaseURL: URL? {
        current?.apiBaseURL
    }

    var passphrase: String? {
        current?.key
    }

    func update(_ config: MotchillRemoteConfig?) {
        lock.withLock {
            storage = config
        }
    }

    func reset() {
        update(nil)
    }
}

protocol MotchillRemoteConfigLoading: AnyObject, Sendable {
    func fetchRemoteConfig() async throws -> MotchillRemoteConfig
}

final class MotchillRemoteConfigClient: MotchillRemoteConfigLoading, @unchecked Sendable {
    private let endpoint: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        endpoint: URL = URL(string: "https://gist.githubusercontent.com/phucnd0604/72a74d2e9bfeee2a004400cb5016dac1/raw/")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.decoder = decoder
    }

    func fetchRemoteConfig() async throws -> MotchillRemoteConfig {
        let (data, response) = try await session.data(from: endpoint)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MotchillRemoteConfigError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw MotchillRemoteConfigError.httpStatus(code: httpResponse.statusCode, url: endpoint)
        }

        let trimmedData = data.trimmingWhitespaceAndNewlines()
        guard !trimmedData.isEmpty else {
            throw MotchillRemoteConfigError.emptyBody
        }

        let config = try decoder.decode(MotchillRemoteConfig.self, from: trimmedData)
        guard config.isValid else {
            throw MotchillRemoteConfigError.invalidPayload
        }

        return config
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private extension Data {
    func trimmingWhitespaceAndNewlines() -> Data {
        let text = String(decoding: self, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(text.utf8)
    }
}
