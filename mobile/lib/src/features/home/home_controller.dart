import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/motchill_repository.dart';
import '../../models.dart';
import '../shared/load_state.dart';

class HomeController extends ChangeNotifier {
  HomeController({required MotchillRepository repository}) : _repository = repository;

  final MotchillRepository _repository;
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  LoadState<List<MovieCard>> _state = const LoadState.idle();

  String get query => _query;
  bool get searching => _searching;
  LoadState<List<MovieCard>> get state => _state;

  List<MovieCard> get items => _state.value ?? const [];

  Future<void> loadHome({bool forceRefresh = false}) async {
    final previous = _state.value;
    _state = LoadState.loading(previous);
    notifyListeners();

    try {
      final cards = await _repository.loadHome();
      _state = LoadState.success(cards);
    } catch (error) {
      if (previous != null && !forceRefresh) {
        _state = LoadState.success(previous);
      } else {
        _state = LoadState.failure(error);
      }
    }

    notifyListeners();
  }

  void searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(search(value));
    });
  }

  Future<void> search(String value) async {
    final trimmed = value.trim();
    _query = trimmed;
    _searching = trimmed.isNotEmpty;
    notifyListeners();

    if (trimmed.isEmpty) {
      return loadHome();
    }

    final previous = _state.value;
    _state = LoadState.loading(previous);
    notifyListeners();

    try {
      final results = await _repository.search(trimmed);
      _state = LoadState.success(results);
    } catch (error) {
      _state = LoadState.failure(error, previous);
    }

    notifyListeners();
  }

  Future<void> refresh() {
    if (_searching && _query.isNotEmpty) {
      return search(_query);
    }

    return loadHome(forceRefresh: true);
  }

  Future<void> clearSearch() async {
    _query = '';
    _searching = false;
    notifyListeners();
    await loadHome();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
