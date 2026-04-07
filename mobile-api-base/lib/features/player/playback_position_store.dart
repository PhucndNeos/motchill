import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPositionStore {
  static const String _prefix = 'player_position';

  String _key(int movieId, int episodeId) => '$_prefix:$movieId:$episodeId';

  Future<void> save(int movieId, int episodeId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(movieId, episodeId), position.inMilliseconds);
  }

  Future<Duration?> load(int movieId, int episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_key(movieId, episodeId));
    if (value is! int || value < 0) {
      return null;
    }
    return Duration(milliseconds: value);
  }
}
