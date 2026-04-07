import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/models/motchill_search_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/features/category/category_view.dart';
import 'package:mobile_api_base/features/home/home_controller.dart';
import 'package:mobile_api_base/features/home/home_view.dart';
import 'package:mobile_api_base/core/storage/liked_movie_store.dart';
import 'package:mobile_api_base/features/search/search_controller.dart'
    as search;
import 'package:mobile_api_base/features/search/search_binding.dart';
import 'package:mobile_api_base/features/search/search_view.dart';

class _FakeRepository extends MotchillRepository {
  _FakeRepository() : super(apiClient: _FakeApiClient());

  @override
  Future<List<HomeSection>> loadHome() async {
    return [
      HomeSection(
        title: 'Slide',
        key: 'slide',
        isCarousel: true,
        products: [
          _movie('Dune: Part Two', subtitle: 'Dune: Part Two'),
          _movie('The Boy and the Heron', subtitle: 'The Boy and the Heron'),
        ],
      ),
      HomeSection(
        title: 'Phim Trung Quá»‘c',
        key: 'phim-trung-quoc',
        isCarousel: true,
        products: [_movie('My Journey', subtitle: 'China drama')],
      ),
    ];
  }

  @override
  Future<PopupAdConfig?> loadPopupAd() async {
    return const PopupAdConfig(
      id: 1,
      name: 'Hero promo',
      type: 'banner',
      desktopLink: 'https://example.com/desktop',
      mobileLink: 'https://example.com/mobile',
    );
  }

  @override
  Future<SearchFilterData> loadSearchFilters() async {
    return SearchFilterData(
      categories: [
        _facet(2, 'Phim bá»™', 'phim-bo'),
        _facet(3, 'Phim láº»', 'phim-le'),
      ],
      countries: [
        _facet(10, 'Trung Quá»‘c', 'trung-quoc'),
        _facet(11, 'Má»¹', 'my'),
      ],
    );
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
      records: [
        _movie('Dune: Part Two', subtitle: 'Sci-fi'),
        _movie('The Boy and the Heron', subtitle: 'Animation'),
      ],
      pagination: const SearchPagination(
        pageIndex: 1,
        pageSize: 10,
        pageCount: 1,
        totalRecords: 2,
      ),
    );
  }
}

class _FakeApiClient extends MotchillApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

MovieCard _movie(String title, {required String subtitle}) {
  return MovieCard(
    id: title.hashCode,
    name: title,
    otherName: subtitle,
    avatar: '',
    bannerThumb: '',
    avatarThumb: '',
    description: '$title description',
    banner: '',
    imageIcon: '',
    link: title.toLowerCase().replaceAll(' ', '-'),
    quantity: '12',
    rating: '8.5',
    year: 2026,
    statusTitle: 'Ongoing',
    countries: const [],
    categories: const [],
  );
}

SearchFacetOption _facet(int id, String name, String slug) {
  return SearchFacetOption(id: id, name: name, slug: slug);
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    Get.put<LikedMovieStore>(LikedMovieStore());
    Get.put<MotchillRepository>(_FakeRepository());
    Get.put<HomeController>(HomeController(Get.find<MotchillRepository>()));
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('home screen shows a single cinematic hero section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const HomeView()),
          GetPage(
            name: '/search',
            page: () => const SearchView(),
            binding: SearchBinding(),
          ),
          GetPage(
            name: '/category/:slug',
            page: () => const CategoryView(),
            binding: SearchBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Xem ngay'), findsOneWidget);
    expect(find.text('Slide'), findsNothing);
    expect(find.text('Phim Trung Quá»‘c'), findsOneWidget);
    expect(find.text('Dune: Part Two'), findsNWidgets(2));
    expect(find.text('The Boy and the Heron'), findsOneWidget);

    await tester.tap(find.text('Favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(Get.currentRoute, startsWith('/search'));
    expect(Get.parameters['likedOnly'], 'true');
    expect(Get.find<search.SearchController>().showLikedOnly.value, isTrue);
  });
}
