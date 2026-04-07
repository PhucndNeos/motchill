import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_api_base/features/player/playback_position_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackPositionStore', () {
    test('round-trips a saved playback position', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PlaybackPositionStore();

      await store.save(10, 20, const Duration(seconds: 42, milliseconds: 350));

      final loaded = await store.load(10, 20);

      expect(loaded, const Duration(seconds: 42, milliseconds: 350));
    });

    test('returns null when the key is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PlaybackPositionStore();

      final loaded = await store.load(10, 20);

      expect(loaded, isNull);
    });

    test('returns null for invalid stored values', () async {
      SharedPreferences.setMockInitialValues({
        'player_position:10:20': 'oops',
      });
      final store = PlaybackPositionStore();

      final loaded = await store.load(10, 20);

      expect(loaded, isNull);
    });
  });
}
