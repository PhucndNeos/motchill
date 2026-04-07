import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_api_base/core/storage/liked_movie_store.dart';

void main() {
  test('liked movie store persists liked ids and toggles membership', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LikedMovieStore();

    expect(await store.loadIds(), isEmpty);
    expect(await store.isLiked(42), isFalse);

    await store.toggle(42);
    expect(await store.isLiked(42), isTrue);

    await store.toggle(42);
    expect(await store.isLiked(42), isFalse);
  });
}
