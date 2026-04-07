import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/motchill_models.dart';

class LikedMovieStore {
  static const _moviesKey = 'liked_movie_cards';
  static const _idsKey = 'liked_movie_ids';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<MovieCard>> loadMovies() async {
    final prefs = await _prefs();
    final encodedMovies = prefs.getStringList(_moviesKey);
    if (encodedMovies != null && encodedMovies.isNotEmpty) {
      return encodedMovies
          .map((encoded) {
            try {
              final decoded = jsonDecode(encoded);
              if (decoded is Map<String, dynamic>) {
                return MovieCard.fromJson(decoded);
              }
              if (decoded is Map) {
                return MovieCard.fromJson(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {
              return null;
            }
            return null;
          })
          .whereType<MovieCard>()
          .toList(growable: false);
    }

    final ids = prefs.getStringList(_idsKey) ?? const <String>[];
    return ids
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .map(_movieFromId)
        .toList(growable: false);
  }

  Future<Set<int>> loadIds() async {
    return (await loadMovies()).map((movie) => movie.id).toSet();
  }

  Future<bool> isLiked(int movieId) async {
    return (await loadIds()).contains(movieId);
  }

  Future<List<MovieCard>> toggleMovie(MovieCard movie) async {
    final movies = await loadMovies();
    final nextMovies = List<MovieCard>.from(movies);
    final index = nextMovies.indexWhere((item) => item.id == movie.id);
    if (index == -1) {
      nextMovies.add(movie);
    } else {
      nextMovies.removeAt(index);
    }
    await _saveMovies(nextMovies);
    return nextMovies;
  }

  Future<Set<int>> toggle(int movieId) async {
    final movies = await loadMovies();
    final nextMovies =
        movies.where((movie) => movie.id != movieId).toList(growable: true);
    if (nextMovies.length == movies.length) {
      nextMovies.add(_movieFromId(movieId));
    }
    await _saveMovies(nextMovies);
    return nextMovies.map((movie) => movie.id).toSet();
  }

  Future<void> _saveMovies(List<MovieCard> movies) async {
    final prefs = await _prefs();
    final encodedMovies = movies
        .map((movie) => jsonEncode(movie.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_moviesKey, encodedMovies);
    await prefs.setStringList(
      _idsKey,
      movies.map((movie) => movie.id.toString()).toList(growable: false),
    );
  }

  MovieCard _movieFromId(int movieId) {
    return MovieCard(
      id: movieId,
      name: 'Movie $movieId',
      otherName: '',
      avatar: '',
      bannerThumb: '',
      avatarThumb: '',
      description: '',
      banner: '',
      imageIcon: '',
      link: '',
      quantity: '',
      rating: '',
      year: 0,
      statusTitle: '',
      countries: const [],
      categories: const [],
    );
  }
}
