import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class MotchillEncryptedPayloadCipher {
  const MotchillEncryptedPayloadCipher._();

  static const passphrase = 'sB7hP!c9X3@rVn\$5mGqT1eLzK!fU8dA2';

  static String decrypt(String encryptedPayload) {
    final data = base64Decode(encryptedPayload.trim());
    if (data.length < 17) {
      throw const FormatException('Encrypted payload is too short');
    }

    final header = utf8.decode(data.sublist(0, 8));
    if (header != 'Salted__') {
      throw const FormatException(
        'Encrypted payload is missing Salted__ header',
      );
    }

    final salt = Uint8List.fromList(data.sublist(8, 16));
    final ciphertext = data.sublist(16);
    final keyIv = _evpBytesToKey(
      utf8.encode(passphrase),
      salt,
      keyLength: 32,
      ivLength: 16,
    );
    final key = Key(Uint8List.fromList(keyIv.sublist(0, 32)));
    final iv = IV(Uint8List.fromList(keyIv.sublist(32, 48)));
    final encrypted = Encrypted(Uint8List.fromList(ciphertext));
    return Encrypter(
      AES(key, mode: AESMode.cbc, padding: 'PKCS7'),
    ).decrypt(encrypted, iv: iv);
  }

  static dynamic decodeJson(String encryptedPayload) {
    return jsonDecode(decrypt(encryptedPayload));
  }

  static Map<String, dynamic> decodeMap(String encryptedPayload) {
    final decoded = decodeJson(encryptedPayload);
    if (decoded is! Map) {
      throw const FormatException('Decrypted payload is not an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static List<T> decodeList<T>(
    String encryptedPayload,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final decoded = decodeJson(encryptedPayload);
    if (decoded is! List) {
      throw const FormatException('Decrypted payload is not a list');
    }
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Uint8List _evpBytesToKey(
    List<int> passphrase,
    Uint8List salt, {
    required int keyLength,
    required int ivLength,
  }) {
    final targetLength = keyLength + ivLength;
    final output = <int>[];
    var previous = <int>[];

    while (output.length < targetLength) {
      final digest = md5.convert(<int>[
        ...previous,
        ...passphrase,
        ...salt,
      ]).bytes;
      output.addAll(digest);
      previous = digest;
    }

    return Uint8List.fromList(
      output.take(targetLength).toList(growable: false),
    );
  }
}
