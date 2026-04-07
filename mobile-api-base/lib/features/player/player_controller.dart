import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../data/models/motchill_play_models.dart';
import '../../data/repositories/motchill_repository.dart';

class PlayerController extends GetxController {
  PlayerController(
    this._repository, {
    required this.movieId,
    required this.episodeId,
    required this.movieTitle,
    required this.episodeLabel,
  });

  final MotchillRepository _repository;
  final int movieId;
  final int episodeId;
  final String movieTitle;
  final String episodeLabel;

  final sources = <PlaySource>[].obs;
  final selectedIndex = 0.obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();

  PlaySource? get selectedSource {
    if (sources.isEmpty) return null;
    final index = selectedIndex.value.clamp(0, sources.length - 1);
    return sources[index];
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    developer.log(
      'Loading episode sources',
      name: 'Motchill.player',
      error: {'movieId': movieId, 'episodeId': episodeId},
    );

    try {
      final loaded = await _repository.loadEpisodeSources(
        movieId: movieId,
        episodeId: episodeId,
      );
      final playableSources = loaded.where((source) => !source.isFrame).toList();
      sources.assignAll(playableSources);
      selectedIndex.value = 0;
      developer.log(
        'Episode sources loaded',
        name: 'Motchill.player',
        error: {
          'count': loaded.length,
          'playableCount': playableSources.length,
          'selected': playableSources.isNotEmpty
              ? {
                  'serverName': playableSources.first.serverName,
                  'link': playableSources.first.link,
                  'isFrame': playableSources.first.isFrame,
                }
              : null,
        },
      );
      if (playableSources.isEmpty) {
        errorMessage.value = 'No source available, try again later';
      }
    } catch (error) {
      developer.log(
        'Episode source load failed',
        name: 'Motchill.player',
        error: error,
      );
      errorMessage.value = error.toString();
      sources.clear();
    } finally {
      isLoading.value = false;
    }
  }

  void selectSource(int index) {
    if (index < 0 || index >= sources.length) return;
    selectedIndex.value = index;
    final source = sources[index];
    developer.log(
      'Selected play source',
      name: 'Motchill.player',
      error: {
        'index': index,
        'serverName': source.serverName,
        'link': source.link,
        'isFrame': source.isFrame,
        'quality': source.quality,
      },
    );
  }

  void selectSourceById(int sourceId) {
    final index = sources.indexWhere((source) => source.sourceId == sourceId);
    if (index >= 0) {
      selectSource(index);
    }
  }

  void selectNextSource() {
    if (sources.length <= 1) return;
    final nextIndex = (selectedIndex.value + 1) % sources.length;
    selectSource(nextIndex);
  }
}
