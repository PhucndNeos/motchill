import XCTest
@testable import PhucTvSwiftUI

final class PhucTvPayloadCipherTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PhucTvRemoteConfigStore.shared.update(
            PhucTvRemoteConfig(
                domain: "https://motchilltv.date",
                key: "sB7hP!c9X3@rVn$5mGqT1eLzK!fU8dA2"
            )
        )
    }

    override func tearDown() {
        PhucTvRemoteConfigStore.shared.reset()
        super.tearDown()
    }

    func testDecryptsOpenSSLSaltedPayload() throws {
        let ciphertext = "U2FsdGVkX1/7NAIkqPsPOrC/sxteu9mz8hZBx2FaPzQSh6Q5dVB+Hfd0csC+mhn5"

        let plaintext = try PhucTvPayloadCipher.decrypt(ciphertext)

        XCTAssertEqual(plaintext, #"{"hello":"world"}"#)
    }

    func testRejectsMissingSaltedHeader() {
        XCTAssertThrowsError(try PhucTvPayloadCipher.decrypt("eyJoZWxsbyI6IndvcmxkIn0=")) { error in
            guard case PhucTvPayloadCipherError.missingSaltedHeader = error else {
                return XCTFail("Expected missingSaltedHeader, got \(error)")
            }
        }
    }

    func testRejectsMissingPassphraseWhenRemoteConfigIsUnavailable() {
        PhucTvRemoteConfigStore.shared.reset()

        XCTAssertThrowsError(try PhucTvPayloadCipher.decrypt("U2FsdGVkX1/7NAIkqPsPOrC/sxteu9mz8hZBx2FaPzQSh6Q5dVB+Hfd0csC+mhn5")) { error in
            guard case PhucTvPayloadCipherError.missingPassphrase = error else {
                return XCTFail("Expected missingPassphrase, got \(error)")
            }
        }
    }
}
