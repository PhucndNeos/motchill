import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/features/detail/detail_controller.dart';
import 'package:mobile_api_base/features/detail/detail_view.dart';
import 'package:mobile_api_base/core/storage/liked_movie_store.dart';

class _FakeRepository extends MotchillRepository {
  _FakeRepository() : super(apiClient: _FakeApiClient());

  @override
  Future<MovieDetail> loadDetail(String slug) async {
    return MovieDetail(
      movie: {
        'Id': 1,
        'Name': 'Oppenheimer',
        'OtherName': 'Oppenheimer (2023)',
        'Avatar': 'https://example.com/poster.jpg',
        'AvatarThumb': 'https://example.com/poster-thumb.jpg',
        'Banner': 'https://example.com/banner.jpg',
        'BannerThumb': 'https://example.com/banner-thumb.jpg',
        'Description': 'The story of J. Robert Oppenheimer.',
        'Quanlity': 'IMAX',
        'StatusTitle': 'Now Showing',
        'StatusRaw': 'raw-status',
        'StatusTMText': 'text-status',
        'Director': 'Christopher Nolan',
        'CastString': 'Cillian Murphy, Emily Blunt, Matt Damon',
        'Time': '180m',
        'ShowTimes': 'IMAX 70mm',
        'MoreInfo': 'Nuclear age drama',
        'Trailer': 'https://example.com/trailer',
        'RatePoint': 8.9,
        'ViewNumber': 123456,
        'Year': 2023,
        'Countries': [
          {'Id': 1, 'Name': 'USA', 'Link': '/usa', 'DisplayColumn': 0},
        ],
        'Categories': [
          {
            'Id': 2,
            'Name': 'Biography',
            'Link': '/biography',
            'DisplayColumn': 0,
          },
        ],
        'Photos': [
          'https://example.com/photo-1.jpg',
          'https://example.com/photo-2.jpg',
        ],
        'PreviewPhotos': ['https://example.com/preview-1.jpg'],
        'Episodes': [
          {
            'Id': 10,
            'EpisodeNumber': 1,
            'Name': 'Prologue',
            'FullLink': 'https://example.com/ep-1',
            'Status': null,
            'Type': 'movie',
          },
        ],
      },
      relatedMovies: [_movie('Interstellar', year: 2014)],
      countries: [
        const SimpleLabel(id: 1, name: 'USA', link: '/usa', displayColumn: 0),
      ],
      categories: [
        const SimpleLabel(
          id: 2,
          name: 'Biography',
          link: '/biography',
          displayColumn: 0,
        ),
      ],
      episodes: [
        const MovieEpisode(
          id: 10,
          episodeNumber: 1,
          name: 'Prologue',
          fullLink: 'https://example.com/ep-1',
          status: null,
          type: 'movie',
        ),
      ],
    );
  }

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

MovieCard _movie(String title, {required int year}) {
  return MovieCard(
    id: title.hashCode,
    name: title,
    otherName: '',
    avatar: 'https://example.com/$title.jpg',
    bannerThumb: '',
    avatarThumb: '',
    description: '',
    banner: '',
    imageIcon: '',
    link: title.toLowerCase().replaceAll(' ', '-'),
    quantity: '1',
    rating: '8.0',
    year: year,
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
    final repository = _FakeRepository();
    Get.put<MotchillRepository>(repository);
    Get.put<LikedMovieStore>(LikedMovieStore());
    Get.lazyPut<DetailController>(
      () => DetailController(repository, slug: 'oppenheimer'),
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('detail screen shows full movie data groups', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/detail/oppenheimer',
        getPages: [
          GetPage(name: '/detail/:slug', page: () => const DetailView()),
          GetPage(
            name: '/play/:movieId/:episodeId',
            page: () => const Scaffold(body: Text('player screen')),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Oppenheimer'), findsWidgets);
    expect(find.text('Oppenheimer (2023)'), findsOneWidget);
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.textContaining('The story of J. Robert Oppenheimer.'), findsNothing);

    final controller = Get.find<DetailController>();
    await tester.tap(find.text('Synopsis'));
    await tester.pumpAndSettle();
    expect(controller.selectedTab.value, DetailSectionTab.synopsis);
    await tester.scrollUntilVisible(
      find.textContaining('The story of J. Robert Oppenheimer.'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('The story of J. Robert Oppenheimer.'), findsOneWidget);

    await controller.toggleLike();
    await tester.pumpAndSettle();
    expect(controller.isLiked.value, isTrue);

    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(controller.selectedTab.value, DetailSectionTab.information);

    await tester.tap(find.text('Xem ngay'));
    await tester.pumpAndSettle();
    expect(find.text('player screen'), findsOneWidget);
  });
}
