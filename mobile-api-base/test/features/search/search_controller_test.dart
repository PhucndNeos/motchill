import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/core/storage/liked_movie_store.dart';
import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/models/motchill_search_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/features/search/search_controller.dart';

class _FakeLikedMovieStore extends LikedMovieStore {
  @override
  Future<List<MovieCard>> loadMovies() async => [_movie(1, 'Liked movie')];

  @override
  Future<Set<int>> loadIds() async => {1};

  @override
  Future<bool> isLiked(int movieId) async => movieId == 1;
}

class _FakeRepository extends MotchillRepository {
  _FakeRepository() : super(apiClient: _FakeApiClient());

  @override
  Future<SearchFilterData> loadSearchFilters() async {
    return SearchFilterData(categories: const [], countries: const []);
  }

  @override
  Future<SearchResults> loadSearchResults({
    int? categoryId,
    int? countryId,
    String typeRaw = '',
    String year = '',
    String orderBy = 'UpdateOn',
    bool isChieuRap = false,
    bool is4k = false,
    String search = '',
    int pageNumber = 1,
  }) async {
    return SearchResults(
      records: const [],
      pagination: const SearchPagination(
        pageIndex: 1,
        pageSize: 10,
        pageCount: 0,
        totalRecords: 0,
      ),
    );
  }
}

class _FakeApiClient extends MotchillApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

MovieCard _movie(int id, String title) {
  return MovieCard(
    id: id,
    name: title,
    otherName: '',
    avatar: '',
    bannerThumb: '',
    avatarThumb: '',
    description: '',
    banner: '',
    imageIcon: '',
    link: title.toLowerCase().replaceAll(' ', '-'),
    quantity: '1',
    rating: '8.0',
    year: 2026,
    statusTitle: 'Available',
    countries: const [],
    categories: const [],
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  test(
    'liked-only filter shows cached liked movies even when api returns none',
    () async {
      final controller = SearchController(
        _FakeRepository(),
        likedMovieStore: _FakeLikedMovieStore(),
      );

      await controller.load();
      expect(controller.movies, isEmpty);
      expect(controller.visibleMovies, isEmpty);

      await controller.toggleLikedOnly();
      expect(controller.showLikedOnly.value, isTrue);
      expect(controller.visibleMovies.map((movie) => movie.id).toList(), [1]);
    },
  );

  test('liked-only route default is honored on init', () async {
    final controller = SearchController(
      _FakeRepository(),
      likedMovieStore: _FakeLikedMovieStore(),
      initialLikedOnly: true,
    );

    await controller.load();

    expect(controller.showLikedOnly.value, isTrue);
    expect(controller.visibleMovies.map((movie) => movie.id).toList(), [1]);
  });
}
