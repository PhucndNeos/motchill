import XCTest
@testable import MotchillSwiftUI

final class MotchillPayloadCipherTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MotchillRemoteConfigStore.shared.update(
            MotchillRemoteConfig(
                domain: "https://motchilltv.date",
                key: "sB7hP!c9X3@rVn$5mGqT1eLzK!fU8dA2"
            )
        )
    }

    override func tearDown() {
        MotchillRemoteConfigStore.shared.reset()
        super.tearDown()
    }

    func testDecryptsOpenSSLSaltedPayload() throws {
        let ciphertext = "U2FsdGVkX1/7NAIkqPsPOrC/sxteu9mz8hZBx2FaPzQSh6Q5dVB+Hfd0csC+mhn5"

        let plaintext = try MotchillPayloadCipher.decrypt(ciphertext)

        XCTAssertEqual(plaintext, #"{"hello":"world"}"#)
    }

    func testRejectsMissingSaltedHeader() {
        XCTAssertThrowsError(try MotchillPayloadCipher.decrypt("eyJoZWxsbyI6IndvcmxkIn0=")) { error in
            guard case MotchillPayloadCipherError.missingSaltedHeader = error else {
                return XCTFail("Expected missingSaltedHeader, got \(error)")
            }
        }
    }

    func testRejectsMissingPassphraseWhenRemoteConfigIsUnavailable() {
        MotchillRemoteConfigStore.shared.reset()

        XCTAssertThrowsError(try MotchillPayloadCipher.decrypt("U2FsdGVkX1/7NAIkqPsPOrC/sxteu9mz8hZBx2FaPzQSh6Q5dVB+Hfd0csC+mhn5")) { error in
            guard case MotchillPayloadCipherError.missingPassphrase = error else {
                return XCTFail("Expected missingPassphrase, got \(error)")
            }
        }
    }
}
