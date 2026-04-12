import Alamofire
import Foundation

enum MotchillAPIError: Error, LocalizedError {
    case invalidURL
    case remoteConfigUnavailable
    case invalidResponse
    case httpStatus(code: Int, url: URL)
    case emptyBody

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The requested URL could not be built."
        case .remoteConfigUnavailable:
            return "Remote config has not been loaded yet."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .httpStatus(code, url):
            return "HTTP \(code) for \(url.absoluteString)"
        case .emptyBody:
            return "The response body was empty."
        }
    }
}

final class MotchillAPIClient {
    private let configuration: AppConfiguration
    private let session: Session
    private let decoder: JSONDecoder

    init(
        configuration: AppConfiguration = AppConfiguration(),
        session: Session? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.decoder = decoder

        let urlSessionConfiguration = URLSessionConfiguration.af.default
        urlSessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
        urlSessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout
        self.session = session ?? Session(configuration: urlSessionConfiguration)
    }

    func fetchHomeSections() async throws -> [MotchillHomeSection] {
        let sections: [MotchillHomeSectionDTO] = try await requestDecodable(path: "/api/moviehomepage")
        return sections.map(\.domain)
    }

    func fetchNavbar() async throws -> [MotchillNavbarItem] {
        let items: [MotchillNavbarItemDTO] = try await requestDecodable(path: "/api/navbar")
        return items.map(\.domain)
    }

    func fetchMovieDetail(slug: String) async throws -> MotchillMovieDetail {
        let detail: MotchillMovieDetailDTO = try await requestDecodable(path: "/api/movie/\(slug.percentEncodedPathComponent)")
        return detail.domain
    }

    func fetchMoviePreview(slug: String) async throws -> MotchillMovieDetail {
        let detail: MotchillMovieDetailDTO = try await requestDecodable(path: "/api/movie/preview/\(slug.percentEncodedPathComponent)")
        return detail.domain
    }

    func fetchSearchFilters() async throws -> MotchillSearchFilterData {
        let filters: MotchillSearchFilterDataDTO = try await requestDecodable(path: "/api/filter")
        return filters.domain
    }

    func fetchSearchResults(
        categoryId: Int? = nil,
        countryId: Int? = nil,
        typeRaw: String = "",
        year: String = "",
        orderBy: String = "UpdateOn",
        isChieuRap: Bool = false,
        is4k: Bool = false,
        search: String = "",
        pageNumber: Int = 1
    ) async throws -> MotchillSearchResults {
        let query: [String: String] = [
            "categoryId": categoryId.map(String.init) ?? "",
            "countryId": countryId.map(String.init) ?? "",
            "typeRaw": typeRaw,
            "year": year,
            "orderBy": orderBy,
            "isChieuRap": String(isChieuRap),
            "is4k": String(is4k),
            "search": search,
            "pageNumber": String(pageNumber),
        ]

        let encryptedPayload = try await requestText(path: "/api/search", query: query)
        let payload = try MotchillPayloadCipher.decrypt(encryptedPayload)
        let data = Data(payload.utf8)
        let results = try decoder.decode(MotchillSearchResultsDTO.self, from: data)
        return results.domain
    }

    func fetchEpisodeSourcesPayload(
        movieId: Int,
        episodeId: Int,
        server: Int = 0
    ) async throws -> String {
        try await requestText(
            path: "/api/play/get",
            query: [
                "movieId": String(movieId),
                "episodeId": String(episodeId),
                "server": String(server),
            ]
        )
    }

    func fetchEpisodeSources(
        movieId: Int,
        episodeId: Int,
        server: Int = 0
    ) async throws -> [MotchillPlaySource] {
        let encryptedPayload = try await fetchEpisodeSourcesPayload(
            movieId: movieId,
            episodeId: episodeId,
            server: server
        )
        let payload = try MotchillPayloadCipher.decrypt(encryptedPayload)
        let data = Data(payload.utf8)
        let sources = try decoder.decode([MotchillPlaySourceDTO].self, from: data)
        return sources.map(\.domain)
    }

    func fetchPopupAd() async throws -> MotchillPopupAdConfig? {
        let text = try await requestText(path: "/api/ads/popup")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.first == "{" else { return nil }
        let data = Data(trimmed.utf8)
        let popup = try decoder.decode(MotchillPopupAdConfigDTO.self, from: data)
        return popup.domain
    }

    private func requestDecodable<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        do {
            let data = try await requestData(path: path, query: query)
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                MotchillLogger.shared.error(
                    error,
                    message: "Failed to decode API response",
                    metadata: [
                        "path": path,
                        "query": queryText(query),
                        "payloadPreview": payloadPreview(from: data),
                    ]
                )
                throw error
            }
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Request failed while decoding API response",
                metadata: [
                    "path": path,
                    "query": queryText(query),
                ]
            )
            throw error
        }
    }

    private func requestData(path: String, query: [String: String] = [:]) async throws -> Data {
        guard let url = makeURL(path: path, query: query) else {
            let error = configuration.apiBaseURL == nil ? MotchillAPIError.remoteConfigUnavailable : MotchillAPIError.invalidURL
            MotchillLogger.shared.error(
                error,
                message: "Invalid API URL",
                metadata: [
                    "path": path,
                    "query": queryText(query),
                ]
            )
            throw error
        }

        let request = session
            .request(
                url,
                method: .get,
                headers: HTTPHeaders(configuration.requestHeaders)
            )
            .validate(statusCode: 200..<300)

        do {
            let data = try await request.serializingData().value
            guard !data.isEmpty else {
                MotchillLogger.shared.warning(
                    "Received empty body from API",
                    metadata: [
                        "path": path,
                        "query": queryText(query),
                    ]
                )
                throw MotchillAPIError.emptyBody
            }
            return data
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Network request failed",
                metadata: [
                    "path": path,
                    "query": queryText(query),
                ]
            )
            throw error
        }
    }

    private func requestText(path: String, query: [String: String] = [:]) async throws -> String {
        guard let url = makeURL(path: path, query: query) else {
            let error = configuration.apiBaseURL == nil ? MotchillAPIError.remoteConfigUnavailable : MotchillAPIError.invalidURL
            MotchillLogger.shared.error(
                error,
                message: "Invalid API URL",
                metadata: [
                    "path": path,
                    "query": queryText(query),
                ]
            )
            throw error
        }

        let request = session
            .request(
                url,
                method: .get,
                headers: HTTPHeaders(configuration.requestHeaders)
            )
            .validate(statusCode: 200..<300)

        do {
            let text = try await request.serializingString().value
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                MotchillLogger.shared.warning(
                    "Received empty text body from API",
                    metadata: [
                        "path": path,
                        "query": queryText(query),
                    ]
                )
                throw MotchillAPIError.emptyBody
            }
            return text
        } catch {
            MotchillLogger.shared.error(
                error,
                message: "Text request failed",
                metadata: [
                    "path": path,
                    "query": queryText(query),
                ]
            )
            throw error
        }
    }

    private func makeURL(path: String, query: [String: String]) -> URL? {
        guard let apiBaseURL = configuration.apiBaseURL else {
            return nil
        }

        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = apiBaseURL.path + path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

    private func queryText(_ query: [String: String]) -> String {
        guard !query.isEmpty else {
            return "-"
        }

        return query
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
    }

    private func payloadPreview(from data: Data) -> String {
        let text = String(decoding: data.prefix(800), as: UTF8.self)
        return text.replacingOccurrences(of: "\n", with: " ")
    }
}

private extension String {
    var percentEncodedPathComponent: String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
