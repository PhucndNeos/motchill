import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/core/storage/liked_movie_store.dart';
import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/features/detail/detail_controller.dart';

class _FakeRepository extends MotchillRepository {
  _FakeRepository(this.detail) : super(apiClient: _FakeApiClient());

  final MovieDetail detail;

  @override
  Future<MovieDetail> loadDetail(String slug) async => detail;

  @override
  Future<List<HomeSection>> loadHome() async => const [];

  @override
  Future<List<NavbarItem>> loadNavbar() async => const [];

  @override
  Future<PopupAdConfig?> loadPopupAd() async => null;
}

class _FakeApiClient extends MotchillApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

MovieDetail _detail({required String trailer, required bool includeInfoTab}) {
  return MovieDetail(
    movie: {
      'Id': 1,
      'Name': 'Movie',
      'OtherName': 'Alt',
      'Avatar': 'https://example.com/avatar.jpg',
      'AvatarThumb': 'https://example.com/avatar-thumb.jpg',
      'Banner': 'https://example.com/banner.jpg',
      'BannerThumb': 'https://example.com/banner-thumb.jpg',
      'Description': includeInfoTab ? 'Description' : '',
      'Quanlity': 'HD',
      'StatusTitle': includeInfoTab ? 'Now Showing' : '',
      'StatusRaw': includeInfoTab ? 'ongoing' : '',
      'StatusTMText': includeInfoTab ? 'Text' : '',
      'Director': includeInfoTab ? 'Director' : '',
      'CastString': includeInfoTab ? 'Cast' : '',
      'Time': includeInfoTab ? '90m' : '',
      'ShowTimes': includeInfoTab ? 'Show times' : '',
      'MoreInfo': includeInfoTab ? 'More info' : '',
      'Trailer': trailer,
      'RatePoint': 8.0,
      'ViewNumber': 100,
      'Year': 2026,
      'Countries': const [],
      'Categories': const [],
      'Episodes': [
        {
          'Id': 10,
          'EpisodeNumber': 1,
          'Name': 'Tập 1',
          'FullLink': 'https://example.com/ep-1',
          'Status': null,
          'Type': 'episode',
        },
      ],
    },
    relatedMovies: const [],
    countries: const [],
    categories: const [],
    episodes: const [
      MovieEpisode(
        id: 10,
        episodeNumber: 1,
        name: 'Tập 1',
        fullLink: 'https://example.com/ep-1',
        status: null,
        type: 'episode',
      ),
    ],
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

  test('opens trailer in external browser when a trailer link exists', () async {
    Uri? launchedUri;
    LaunchMode? launchedMode;
    final repository = _FakeRepository(
      _detail(trailer: 'https://example.com/trailer', includeInfoTab: true),
    );
    final controller = DetailController(
      repository,
      slug: 'movie',
      likedMovieStore: LikedMovieStore(),
      browserOpener: (uri, mode) async {
        launchedUri = uri;
        launchedMode = mode;
      },
    );

    await controller.load();
    await controller.openTrailer();

    expect(launchedUri?.toString(), 'https://example.com/trailer');
    expect(launchedMode, LaunchMode.externalApplication);
  });

  test('jumps to information tab when it exists', () async {
    final repository = _FakeRepository(
      _detail(trailer: 'https://example.com/trailer', includeInfoTab: true),
    );
    final controller = DetailController(
      repository,
      slug: 'movie',
      likedMovieStore: LikedMovieStore(),
    );

    await controller.load();
    expect(controller.selectedTab.value, DetailSectionTab.episodes);

    controller.openInformationTabIfAvailable();

    expect(controller.selectedTab.value, DetailSectionTab.information);
  });

  test('keeps the current tab when information is not available', () async {
    final repository = _FakeRepository(
      _detail(trailer: '', includeInfoTab: false),
    );
    final controller = DetailController(
      repository,
      slug: 'movie',
      likedMovieStore: LikedMovieStore(),
    );

    await controller.load();
    final before = controller.selectedTab.value;

    controller.openInformationTabIfAvailable();

    expect(controller.selectedTab.value, before);
  });
}
