import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../../data/models/motchill_models.dart';
import '../../data/models/motchill_search_models.dart';
import '../config/api_config.dart';
import '../security/motchill_encrypted_payload_cipher.dart';

class MotchillApiClient {
  MotchillApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<List<HomeSection>> fetchHomeSections() async {
    final json = await _getJson('/api/moviehomepage');
    if (json is! List) {
      throw const FormatException('Home API did not return a list');
    }
    return json
        .map(
          (item) =>
              HomeSection.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<List<NavbarItem>> fetchNavbar() async {
    final json = await _getJson('/api/navbar');
    if (json is! List) {
      throw const FormatException('Navbar API did not return a list');
    }
    return json
        .map(
          (item) => NavbarItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<MovieDetail> fetchMovieDetail(String slug) async {
    final json = await _getJson('/api/movie/${Uri.encodeComponent(slug)}');
    if (json is! Map) {
      throw const FormatException('Movie detail API did not return an object');
    }
    return MovieDetail.fromJson(Map<String, dynamic>.from(json));
  }

  Future<MovieDetail> fetchMoviePreview(String slug) async {
    final json = await _getJson(
      '/api/movie/preview/${Uri.encodeComponent(slug)}',
    );
    if (json is! Map) {
      throw const FormatException('Movie preview API did not return an object');
    }
    return MovieDetail.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SearchFilterData> fetchSearchFilters() async {
    final json = await _getJson('/api/filter');
    if (json is! Map) {
      throw const FormatException('Filter API did not return an object');
    }
    return SearchFilterData.fromJson(Map<String, dynamic>.from(json));
  }

  Future<SearchResults> fetchSearchResults({
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
    final payload = await _getText('/api/search', {
      'categoryId': categoryId?.toString() ?? '',
      'countryId': countryId?.toString() ?? '',
      'typeRaw': typeRaw,
      'year': year,
      'orderBy': orderBy,
      'isChieuRap': isChieuRap,
      'is4k': is4k,
      'search': search,
      'pageNumber': pageNumber,
    });

    return SearchResults.fromJson(
      MotchillEncryptedPayloadCipher.decodeMap(payload),
    );
  }

  Future<String> fetchEpisodeSourcesPayload({
    required int movieId,
    required int episodeId,
    int server = 0,
  }) async {
    final response = await _client
        .get(
          _uri('/api/play/get', {
            'movieId': movieId,
            'episodeId': episodeId,
            'server': server,
          }),
          headers: ApiConfig.headers(),
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'HTTP ${response.statusCode}',
        response.request?.url,
      );
    }

    return utf8.decode(response.bodyBytes);
  }

  Future<PopupAdConfig?> fetchPopupAd() async {
    final json = await _getJson('/api/ads/popup');
    if (json is! Map) return null;
    return PopupAdConfig.fromJson(Map<String, dynamic>.from(json));
  }

  Future<dynamic> _getJson(String path, [Map<String, dynamic>? query]) async {
    final text = await _getText(path, query);
    return jsonDecode(text);
  }

  Future<String> _getText(String path, [Map<String, dynamic>? query]) async {
    developer.log(
      'API request',
      name: 'MotchillApiClient',
      error: {'path': path, 'query': query}.toString(),
    );
    final response = await _client
        .get(
          _uri(path, query),
          headers: ApiConfig.headers(),
        )
        .timeout(ApiConfig.requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'HTTP ${response.statusCode}',
        response.request?.url,
      );
    } else{
      developer.log(
        'API response',
        name: 'MotchillApiClient',
        error: {
          'path': path,
          'query': query,
          'response': response.body.toString(),
        },
      );
    }

    return utf8.decode(response.bodyBytes);
  }

  void dispose() {
    _client.close();
  }
}
