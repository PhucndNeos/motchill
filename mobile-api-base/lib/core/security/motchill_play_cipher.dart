import 'dart:developer' as developer;

import '../../data/models/motchill_play_models.dart';
import 'motchill_encrypted_payload_cipher.dart';

class MotchillPlayCipher {
  const MotchillPlayCipher._();

  static const passphrase = MotchillEncryptedPayloadCipher.passphrase;

  static List<PlaySource> decodeSources(String encryptedPayload) {
    developer.log(
      'Decoding play payload',
      name: 'Motchill.play',
      error: {'payloadLength': encryptedPayload.length},
    );
    final sources = MotchillEncryptedPayloadCipher.decodeList(
      encryptedPayload,
      (json) => PlaySource.fromJson(json),
    );
    developer.log(
      'Decoded play sources',
      name: 'Motchill.play',
      error: {
        'count': sources.length,
        'sources': sources
            .map(
              (source) => {
                'serverName': source.serverName,
                'link': source.link,
                'isFrame': source.isFrame,
                'quality': source.quality,
              },
            )
            .toList(growable: false),
      },
    );
    return sources;
  }
}
