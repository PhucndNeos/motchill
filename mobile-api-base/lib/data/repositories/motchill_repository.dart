import '../models/motchill_models.dart';
import '../models/motchill_search_models.dart';
import '../models/motchill_play_models.dart';
import '../../core/network/motchill_api_client.dart';
import '../../core/security/motchill_play_cipher.dart';

class MotchillRepository {
  MotchillRepository({required MotchillApiClient apiClient})
    : _apiClient = apiClient;

  final MotchillApiClient _apiClient;

  Future<List<HomeSection>> loadHome() => _apiClient.fetchHomeSections();

  Future<List<NavbarItem>> loadNavbar() => _apiClient.fetchNavbar();

  Future<MovieDetail> loadDetail(String slug) =>
      _apiClient.fetchMovieDetail(slug);

  Future<MovieDetail> loadPreview(String slug) =>
      _apiClient.fetchMoviePreview(slug);

  Future<SearchFilterData> loadSearchFilters() =>
      _apiClient.fetchSearchFilters();

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
  }) {
    return _apiClient.fetchSearchResults(
      categoryId: categoryId,
      countryId: countryId,
      typeRaw: typeRaw,
      year: year,
      orderBy: orderBy,
      isChieuRap: isChieuRap,
      is4k: is4k,
      search: search,
      pageNumber: pageNumber,
    );
  }

  Future<List<PlaySource>> loadEpisodeSources({
    required int movieId,
    required int episodeId,
    int server = 0,
  }) async {
    final payload = await _apiClient.fetchEpisodeSourcesPayload(
      movieId: movieId,
      episodeId: episodeId,
      server: server,
    );
    return MotchillPlayCipher.decodeSources(payload);
  }

  Future<PopupAdConfig?> loadPopupAd() => _apiClient.fetchPopupAd();

  void dispose() => _apiClient.dispose();
}
