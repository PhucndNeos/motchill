import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/models.dart';

void main() {
  test('PlaybackInfo exposes source choices from playback payload', () {
    final playback = PlaybackInfo.fromJson({
      'movieId': 1,
      'episodeId': 2,
      'server': 0,
      'playbackKind': 'hls',
      'streamUrl': 'https://example.com/master.m3u8',
      'mediaUrl': 'https://example.com/master.m3u8',
      'mediaReferer': 'https://example.com',
      'sources': [
        {
          'index': 0,
          'label': 'Vietsub 1',
          'available': true,
          'playbackKind': 'hls',
          'mediaUrl': 'https://example.com/1.m3u8',
          'mediaReferer': 'https://example.com',
        },
        {
          'index': 1,
          'label': 'Vietsub 2',
          'available': false,
          'playbackKind': 'unsupported',
          'mediaUrl': '',
          'mediaReferer': '',
        },
      ],
      'raw': [],
    });

    expect(playback.sourceChoices.map((choice) => choice.label), [
      'Vietsub 1',
      'Vietsub 2',
    ]);
    expect(playback.sourceChoices.first.available, isTrue);
    expect(playback.sourceChoices.last.available, isFalse);
  });
}
