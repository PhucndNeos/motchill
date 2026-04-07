import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

import '../../data/models/motchill_models.dart';
import '../../data/repositories/motchill_repository.dart';
import '../../core/storage/liked_movie_store.dart';

enum DetailSectionTab {
  episodes,
  synopsis,
  information,
  classification,
  gallery,
  related,
}

extension DetailSectionTabLabel on DetailSectionTab {
  String get label {
    switch (this) {
      case DetailSectionTab.episodes:
        return 'Episodes';
      case DetailSectionTab.synopsis:
        return 'Synopsis';
      case DetailSectionTab.information:
        return 'Information';
      case DetailSectionTab.classification:
        return 'Classification';
      case DetailSectionTab.gallery:
        return 'Gallery';
      case DetailSectionTab.related:
        return 'Related';
    }
  }
}

class DetailController extends GetxController {
  DetailController(
    this._repository, {
    LikedMovieStore? likedMovieStore,
    required this.slug,
    Future<void> Function(Uri uri, LaunchMode mode)? browserOpener,
  })  : _likedMovieStore = likedMovieStore ?? Get.find<LikedMovieStore>(),
        _browserOpener = browserOpener ?? _defaultBrowserOpener;
  static Future<void> _defaultBrowserOpener(Uri uri, LaunchMode mode) async {
    await launchUrl(uri, mode: mode);
  }

  final MotchillRepository _repository;
  final LikedMovieStore _likedMovieStore;
  final Future<void> Function(Uri uri, LaunchMode mode) _browserOpener;
  final String slug;

  final detail = Rxn<MovieDetail>();
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final selectedTab = DetailSectionTab.episodes.obs;
  final isLiked = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final movieDetail = await _repository.loadDetail(slug);
      detail.value = movieDetail;
      selectedTab.value = _defaultTab(movieDetail);
      isLiked.value = movieDetail.id > 0
          ? await _likedMovieStore.isLiked(movieDetail.id)
          : false;
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void selectTab(DetailSectionTab tab) {
    selectedTab.value = tab;
  }

  Future<void> toggleLike() async {
    final movieDetail = detail.value;
    if (movieDetail == null || movieDetail.id == 0) return;
    await _likedMovieStore.toggleMovie(
      MovieCard(
        id: movieDetail.id,
        name: movieDetail.title,
        otherName: movieDetail.otherName,
        avatar: movieDetail.avatar,
        bannerThumb: movieDetail.bannerThumb,
        avatarThumb: movieDetail.avatarThumb,
        description: movieDetail.description,
        banner: movieDetail.banner,
        imageIcon: '',
        link: movieDetail.movie['Link']?.toString() ?? '',
        quantity: movieDetail.quality,
        rating: movieDetail.ratePoint > 0
            ? movieDetail.ratePoint.toStringAsFixed(1)
            : '',
        year: movieDetail.year,
        statusTitle: movieDetail.statusTitle,
        countries: movieDetail.countries,
        categories: movieDetail.categories,
      ),
    );
    isLiked.value = !isLiked.value;
  }

  List<DetailSectionTab> get availableTabs {
    final movieDetail = detail.value;
    if (movieDetail == null) return const [];
    return _availableTabs(movieDetail);
  }

  Future<void> openTrailer() async {
    final movieDetail = detail.value;
    if (movieDetail == null) return;
    final trailer = movieDetail.trailer.trim();
    if (trailer.isEmpty) return;

    final uri = Uri.tryParse(trailer);
    if (uri == null) return;

    await _browserOpener(uri, LaunchMode.externalApplication);
  }

  void openInformationTabIfAvailable() {
    if (availableTabs.contains(DetailSectionTab.information)) {
      selectedTab.value = DetailSectionTab.information;
    }
  }

  DetailSectionTab _defaultTab(MovieDetail movieDetail) {
    final tabs = _availableTabs(movieDetail);
    if (tabs.isEmpty) return DetailSectionTab.synopsis;
    if (tabs.contains(DetailSectionTab.episodes)) {
      return DetailSectionTab.episodes;
    }
    return tabs.first;
  }

  List<DetailSectionTab> _availableTabs(MovieDetail movieDetail) {
    final tabs = <DetailSectionTab>[];
    if (movieDetail.episodes.isNotEmpty) {
      tabs.add(DetailSectionTab.episodes);
    }
    if (movieDetail.description.trim().isNotEmpty) {
      tabs.add(DetailSectionTab.synopsis);
    }
    if (_hasInfo(movieDetail)) {
      tabs.add(DetailSectionTab.information);
    }
    if (movieDetail.countries.isNotEmpty || movieDetail.categories.isNotEmpty) {
      tabs.add(DetailSectionTab.classification);
    }
    if (movieDetail.photoUrls.isNotEmpty ||
        movieDetail.previewPhotoUrls.isNotEmpty) {
      tabs.add(DetailSectionTab.gallery);
    }
    if (movieDetail.relatedMovies.isNotEmpty) {
      tabs.add(DetailSectionTab.related);
    }
    return tabs;
  }

  bool _hasInfo(MovieDetail movieDetail) {
    return movieDetail.director.trim().isNotEmpty ||
        movieDetail.castString.trim().isNotEmpty ||
        movieDetail.showTimes.trim().isNotEmpty ||
        movieDetail.moreInfo.trim().isNotEmpty ||
        movieDetail.trailer.trim().isNotEmpty ||
        movieDetail.statusRaw.trim().isNotEmpty ||
        movieDetail.statusText.trim().isNotEmpty;
  }
}
