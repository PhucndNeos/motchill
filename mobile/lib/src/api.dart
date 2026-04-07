import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class MotchillApi {
  MotchillApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _client;
  final String baseUrl;

  static Future<MotchillApi> create({
    http.Client? client,
    String? baseUrl,
  }) async {
    final resolvedBaseUrl = baseUrl ?? await _resolveBaseUrl();
    return MotchillApi(client: client, baseUrl: resolvedBaseUrl);
  }

  static String _defaultBaseUrl() {
    const envUrl = String.fromEnvironment('MOTCHILL_API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
  }

  static Future<String> _resolveBaseUrl() async {
    const envUrl = String.fromEnvironment('MOTCHILL_API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';

    for (final candidate in const ['http://127.0.0.1:3000', 'http://localhost:3000']) {
      if (await _isReachable(candidate)) {
        return candidate;
      }
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
        includeLoopback: false,
      );
      final addresses = interfaces
          .expand((interface) => interface.addresses)
          .map((address) => address.address)
          .where((address) => address != '0.0.0.0')
          .toList();

      for (final address in addresses) {
        if (address.startsWith('192.168.') ||
            address.startsWith('10.') ||
            address.startsWith('172.16.') ||
            address.startsWith('172.17.') ||
            address.startsWith('172.18.') ||
            address.startsWith('172.19.') ||
            address.startsWith('172.20.') ||
            address.startsWith('172.21.') ||
            address.startsWith('172.22.') ||
            address.startsWith('172.23.') ||
            address.startsWith('172.24.') ||
            address.startsWith('172.25.') ||
            address.startsWith('172.26.') ||
            address.startsWith('172.27.') ||
            address.startsWith('172.28.') ||
            address.startsWith('172.29.') ||
            address.startsWith('172.30.') ||
            address.startsWith('172.31.')) {
          return 'http://$address:3000';
        }
      }

      if (addresses.isNotEmpty) {
        return 'http://${addresses.first}:3000';
      }
    } catch (_) {
      // Fall back below.
    }

    return 'http://127.0.0.1:3000';
  }

  static Future<bool> _isReachable(String baseUrl) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/health'));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<List<MovieCard>> fetchHome() async {
    final response = await _client
        .get(_uri('/api/home'))
        .timeout(const Duration(seconds: 15));
    _ensureOk(response);
    return _decodeCardList(
      response.body,
      'cards',
    ).map(MovieCard.fromJson).toList();
  }

  Future<List<MovieCard>> search(String query) async {
    final response = await _client
        .get(_uri('/api/search', {'q': query}))
        .timeout(const Duration(seconds: 15));
    _ensureOk(response);
    return _decodeCardList(
      response.body,
      'cards',
    ).map(MovieCard.fromJson).toList();
  }

  Future<MovieDetail> fetchDetail(String slug) async {
    final response = await _client
        .get(_uri('/api/movie/${Uri.encodeComponent(slug)}'))
        .timeout(const Duration(seconds: 15));
    _ensureOk(response);
    return MovieDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PlaybackInfo> fetchPlayback(
    String slug, {
    int server = 0,
    bool allowFallback = true,
  }) async {
    final response = await _client
        .get(
          _uri('/api/playback/${Uri.encodeComponent(slug)}', {
            'server': server,
            'fallback': allowFallback ? 1 : 0,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _ensureOk(response);
    return PlaybackInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _decodeCardList(String body, String key) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return (decoded[key] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw http.ClientException(
      'HTTP ${response.statusCode}',
      response.request?.url,
    );
  }

  void dispose() {
    _client.close();
  }
}
