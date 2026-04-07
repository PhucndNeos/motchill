import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_api_base/core/security/motchill_play_cipher.dart';

void main() {
  test('decodes OpenSSL salted play payload into sources', () {
    final payload = _encryptOpenSsl([
      {
        'SourceId': 631493,
        'ServerName': 'Vietsub 1',
        'Link': 'https://example.com/stream.m3u8',
        'Subtitle': '',
        'Type': 1,
        'IsFrame': false,
        'Tracks': [
          {
            'kind': 'captions',
            'file': 'https://example.com/sub.vtt',
            'label': 'Tiếng Việt',
            'default': true,
          },
        ],
      },
      {
        'SourceId': 631501,
        'ServerName': 'Vietsub 4K',
        'Link': 'https://example.com/embed',
        'Subtitle': 'https://example.com/sub.vtt',
        'Quality': '4k',
        'Type': 1,
        'IsFrame': true,
        'Tracks': const [],
      },
    ]);

    final sources = MotchillPlayCipher.decodeSources(payload);

    expect(sources, hasLength(2));
    expect(sources.first.serverName, 'Vietsub 1');
    expect(sources.first.link, 'https://example.com/stream.m3u8');
    expect(sources.first.tracks.single.label, 'Tiếng Việt');
    expect(sources.last.isFrame, isTrue);
    expect(sources.last.quality, '4k');
  });
}

String _encryptOpenSsl(List<Map<String, Object?>> payload) {
  const passphrase = 'sB7hP!c9X3@rVn\$5mGqT1eLzK!fU8dA2';
  final salt = Uint8List.fromList(List<int>.generate(8, (index) => index + 1));
  final keyIv = _evpBytesToKey(utf8.encode(passphrase), salt, 32, 16);
  final key = Key(Uint8List.fromList(keyIv.sublist(0, 32)));
  final iv = IV(Uint8List.fromList(keyIv.sublist(32, 48)));
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final encrypted = encrypter.encrypt(jsonEncode(payload), iv: iv).bytes;
  final bytes = <int>[...utf8.encode('Salted__'), ...salt, ...encrypted];
  return base64Encode(bytes);
}

Uint8List _evpBytesToKey(
  List<int> passphrase,
  Uint8List salt,
  int keyLength,
  int ivLength,
) {
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

  return Uint8List.fromList(output.take(targetLength).toList(growable: false));
}
