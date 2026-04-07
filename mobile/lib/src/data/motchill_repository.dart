import '../api.dart';
import '../models.dart';

class MotchillRepository {
  MotchillRepository({MotchillApi? api}) : _api = api ?? MotchillApi();

  MotchillRepository.fromApi(this._api);

  final MotchillApi _api;

  static Future<MotchillRepository> create() async {
    final api = await MotchillApi.create();
    return MotchillRepository.fromApi(api);
  }

  Future<List<MovieCard>> loadHome() => _api.fetchHome();

  Future<List<MovieCard>> search(String query) => _api.search(query);

  Future<MovieDetail> loadDetail(String slug) => _api.fetchDetail(slug);

  Future<PlaybackInfo> resolvePlayback(
    String slug, {
    int server = 0,
    bool allowFallback = true,
  }) => _api.fetchPlayback(slug, server: server, allowFallback: allowFallback);

  void dispose() {
    _api.dispose();
  }
}
