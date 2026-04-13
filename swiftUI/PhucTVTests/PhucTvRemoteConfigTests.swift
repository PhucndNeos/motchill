import Foundation
import XCTest
@testable import PhucTvSwiftUI

@MainActor
final class PhucTvRemoteConfigTests: XCTestCase {
    override func tearDown() {
        PhucTvRemoteConfigStore.shared.reset()
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testClientFetchesRemoteConfigFromEndpoint() async throws {
        let expectedJSON = """
        {
          "domain": "https://example.com",
          "key": "secret-key"
        }
        """

        let session = makeMockSession { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(expectedJSON.utf8))
        }

        let client = PhucTvRemoteConfigClient(session: session)
        let config = try await client.fetchRemoteConfig()

        XCTAssertEqual(config.domain, "https://example.com")
        XCTAssertEqual(config.key, "secret-key")
    }

    func testAPIClientFailsImmediatelyWithoutRemoteConfig() async {
        PhucTvRemoteConfigStore.shared.reset()

        let client = PhucTvAPIClient(configuration: AppConfiguration())

        do {
            _ = try await client.fetchHomeSections()
            XCTFail("Expected remoteConfigUnavailable")
        } catch let error as PhucTvAPIError {
            switch error {
            case .remoteConfigUnavailable:
                break
            default:
                XCTFail("Expected remoteConfigUnavailable, got \(error)")
            }
        } catch {
            XCTFail("Expected PhucTvAPIError, got \(error)")
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Missing request handler")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    MockURLProtocol.requestHandler = handler

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}
