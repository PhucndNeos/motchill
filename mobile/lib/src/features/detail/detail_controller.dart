import 'package:flutter/foundation.dart';

import '../../data/motchill_repository.dart';
import '../../models.dart';
import '../shared/load_state.dart';

class DetailController extends ChangeNotifier {
  DetailController({
    required MotchillRepository repository,
    required this.movieSlug,
  }) : _repository = repository;

  final MotchillRepository _repository;
  final String movieSlug;

  LoadState<MovieDetail> _state = const LoadState.idle();
  int _selectedIndex = 0;

  LoadState<MovieDetail> get state => _state;
  int get selectedIndex => _selectedIndex;

  MovieDetail? get detail => _state.value;
  List<EpisodeInfo> get episodes {
    final current = detail;
    if (current == null) return const [];
    return current.episodes.isNotEmpty ? current.episodes : [current.episode];
  }

  EpisodeInfo? get selectedEpisode {
    final list = episodes;
    if (list.isEmpty) return null;
    final index = _selectedIndex.clamp(0, list.length - 1);
    return list[index];
  }

  Future<void> load() async {
    final previous = _state.value;
    _state = LoadState.loading(previous);
    notifyListeners();

    try {
      final result = await _repository.loadDetail(movieSlug);
      _state = LoadState.success(result);
      _selectedIndex = 0;
    } catch (error) {
      _state = LoadState.failure(error, previous);
    }

    notifyListeners();
  }

  void selectEpisode(int index) {
    final list = episodes;
    if (list.isEmpty) return;
    _selectedIndex = index.clamp(0, list.length - 1);
    notifyListeners();
  }

  Future<PlaybackInfo> resolveSelectedPlayback() {
    final episode = selectedEpisode;
    if (episode == null) {
      throw StateError('No episode available');
    }
    return _repository.resolvePlayback(episode.slug);
  }
}
