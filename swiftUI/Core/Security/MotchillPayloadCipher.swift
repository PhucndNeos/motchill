import Foundation
import CommonCrypto

enum MotchillPayloadCipherError: Error, LocalizedError {
    case invalidBase64
    case tooShort
    case missingSaltedHeader
    case missingPassphrase
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Encrypted payload is not valid base64."
        case .tooShort:
            return "Encrypted payload is too short."
        case .missingSaltedHeader:
            return "Encrypted payload is missing the Salted__ header."
        case .missingPassphrase:
            return "Remote config passphrase is not available."
        case .decryptionFailed:
            return "Encrypted payload could not be decrypted."
        }
    }
}

enum MotchillPayloadCipher {
    static func decrypt(_ encryptedPayload: String) throws -> String {
        let trimmed = encryptedPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]) else {
            throw MotchillPayloadCipherError.invalidBase64
        }

        guard data.count >= 17 else {
            throw MotchillPayloadCipherError.tooShort
        }

        let header = data.prefix(8)
        guard String(data: header, encoding: .utf8) == "Salted__" else {
            throw MotchillPayloadCipherError.missingSaltedHeader
        }

        let salt = Data(data[8..<16])
        let ciphertext = Data(data[16...])
        guard let passphrase = AppConfiguration().passphrase else {
            throw MotchillPayloadCipherError.missingPassphrase
        }
        let keyAndIV = evpBytesToKey(
            passphrase: Array(passphrase.utf8),
            salt: [UInt8](salt),
            keyLength: 32,
            ivLength: 16
        )

        let key = Data(keyAndIV.prefix(32))
        let iv = Data(keyAndIV.suffix(16))
        let plaintext = try aes256CBCDecrypt(ciphertext: ciphertext, key: key, iv: iv)

        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw MotchillPayloadCipherError.decryptionFailed
        }

        return text
    }

    private static func aes256CBCDecrypt(ciphertext: Data, key: Data, iv: Data) throws -> Data {
        let keyLength = key.count
        let ivLength = iv.count
        guard keyLength == kCCKeySizeAES256, ivLength == kCCBlockSizeAES128 else {
            throw MotchillPayloadCipherError.decryptionFailed
        }

        let outputCount = ciphertext.count + kCCBlockSizeAES128
        var output = Data(count: outputCount)
        var bytesDecrypted: size_t = 0

        let status: CCCryptorStatus = output.withUnsafeMutableBytes { outputBytes in
            ciphertext.withUnsafeBytes { ciphertextBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            keyLength,
                            ivBytes.baseAddress,
                            ciphertextBytes.baseAddress,
                            ciphertext.count,
                            outputBytes.baseAddress,
                            outputCount,
                            &bytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw MotchillPayloadCipherError.decryptionFailed
        }

        output.removeSubrange(bytesDecrypted..<output.count)
        return output
    }

    private static func evpBytesToKey(
        passphrase: [UInt8],
        salt: [UInt8],
        keyLength: Int,
        ivLength: Int
    ) -> [UInt8] {
        let targetLength = keyLength + ivLength
        var output: [UInt8] = []
        output.reserveCapacity(targetLength)
        var previous: [UInt8] = []

        while output.count < targetLength {
            let buffer = previous + passphrase + salt
            let md5 = buffer.withUnsafeBytes { bytes -> [UInt8] in
                var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
                _ = CC_MD5(bytes.baseAddress, CC_LONG(buffer.count), &digest)
                return digest
            }
            output.append(contentsOf: md5)
            previous = md5
        }

        return Array(output.prefix(targetLength))
    }
}
