import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/motchill_repository.dart';
import '../../models.dart';
import '../shared/load_state.dart';

enum PlayerScaleMode {
  contain('Fit', BoxFit.contain),
  zoom('Zoom', BoxFit.cover),
  fill('Fill', BoxFit.fill);

  const PlayerScaleMode(this.label, this.boxFit);

  final String label;
  final BoxFit boxFit;

  PlayerScaleMode get next {
    switch (this) {
      case PlayerScaleMode.contain:
        return PlayerScaleMode.zoom;
      case PlayerScaleMode.zoom:
        return PlayerScaleMode.fill;
      case PlayerScaleMode.fill:
        return PlayerScaleMode.contain;
    }
  }
}

class PlayerController extends ChangeNotifier {
  static const Duration _initializeTimeout = Duration(seconds: 30);

  PlayerController({
    required MotchillRepository repository,
    required MovieDetail detail,
    int initialIndex = 0,
  }) : _repository = repository,
       _detail = detail {
    _selectedIndex = initialIndex.clamp(0, _episodes.length - 1);
  }

  final MotchillRepository _repository;
  final MovieDetail _detail;
  VideoPlayerController? _videoController;
  Timer? _ticker;
  LoadState<PlaybackInfo> _state = const LoadState.idle();
  int _selectedIndex = 0;
  int _selectedSourceIndex = 0;
  int _loadToken = 0;
  PlayerScaleMode _scaleMode = PlayerScaleMode.zoom;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  String? _error;

  MovieDetail get detail => _detail;
  List<EpisodeInfo> get _episodes =>
      _detail.episodes.isNotEmpty ? _detail.episodes : [_detail.episode];

  List<EpisodeInfo> get episodes => _episodes;
  int get selectedIndex => _selectedIndex;
  int get selectedSourceIndex => _selectedSourceIndex;
  List<PlaybackSourceChoice> get sourceChoices {
    final playbackChoices = _state.value?.sourceChoices;
    if (playbackChoices != null && playbackChoices.isNotEmpty) {
      return playbackChoices;
    }
    return _detail.sourceChoices;
  }

  PlayerScaleMode get scaleMode => _scaleMode;
  LoadState<PlaybackInfo> get state => _state;
  VideoPlayerController? get videoController => _videoController;
  EpisodeInfo get currentEpisode => _episodes[_selectedIndex];
  PlaybackSourceChoice get currentSource {
    final choices = sourceChoices;
    if (choices.isEmpty) {
      return const PlaybackSourceChoice(
        index: 0,
        label: 'Source 1',
        available: false,
        playbackKind: 'unsupported',
        mediaUrl: '',
        mediaReferer: '',
        raw: null,
      );
    }
    final index = _selectedSourceIndex.clamp(0, choices.length - 1);
    return choices[index];
  }

  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get buffered => _buffered;
  bool get isInitialized => _videoController?.value.isInitialized ?? false;
  bool get isPlaying => _videoController?.value.isPlaying ?? false;
  bool get isBuffering => _videoController?.value.isBuffering ?? false;
  bool get hasPrevious => _selectedIndex > 0;
  bool get hasNext => _selectedIndex < _episodes.length - 1;

  Future<bool> loadSelectedEpisode() =>
      loadEpisode(_selectedIndex, allowSourceFallback: true);

  Future<bool> loadEpisode(
    int index, {
    bool allowSourceFallback = false,
  }) async {
    final token = ++_loadToken;
    final clamped = index.clamp(0, _episodes.length - 1);
    _selectedIndex = clamped;
    _error = null;
    _state = const LoadState.loading();
    notifyListeners();

    await _disposeVideoController();
    if (token != _loadToken) return false;

    final prepared = await _preparePlayback(
      episodeIndex: _selectedIndex,
      sourceIndex: _selectedSourceIndex,
      allowSourceFallback: allowSourceFallback,
    );

    if (token != _loadToken) {
      await prepared?.controller.dispose();
      return false;
    }

    if (prepared == null) {
      final error = StateError(_error ?? 'Unable to start playback');
      _state = LoadState.failure(error);
      notifyListeners();
      return false;
    }

    _videoController = prepared.controller;
    _selectedSourceIndex = prepared.sourceIndex;
    try {
      await _startPlayback(prepared.playback, token: token);
      return true;
    } catch (error) {
      await prepared.controller.dispose();
      if (token != _loadToken) return false;
      _videoController = null;
      _error = error.toString();
      _state = LoadState.failure(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> selectSource(int index) async {
    final choices = sourceChoices;
    if (choices.isEmpty) return false;

    final clamped = index.clamp(0, choices.length - 1);
    if (!choices[clamped].available) {
      return false;
    }
    if (clamped == _selectedSourceIndex && isInitialized) {
      return true;
    }

    final prepared = await _preparePlayback(
      episodeIndex: _selectedIndex,
      sourceIndex: clamped,
      allowSourceFallback: false,
    );
    if (prepared == null) {
      return false;
    }

    final previousController = _videoController;
    final previousSource = _selectedSourceIndex;
    _videoController = prepared.controller;
    _selectedSourceIndex = prepared.sourceIndex;

    try {
      await _startPlayback(prepared.playback, token: _loadToken);
      _error = null;
      await previousController?.dispose();
      return true;
    } catch (error) {
      await prepared.controller.dispose();
      _videoController = previousController;
      _selectedSourceIndex = previousSource;
      if (_videoController != null) {
        _restartTicker();
      }
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final clampedMilliseconds = position.inMilliseconds.clamp(
      0,
      duration.inMilliseconds,
    );
    final clampedPosition = Duration(milliseconds: clampedMilliseconds);
    await controller.seekTo(clampedPosition);
    _position = clampedPosition;
    notifyListeners();
  }

  Future<void> nextEpisode() async {
    if (!hasNext) return;
    await loadEpisode(_selectedIndex + 1);
  }

  Future<void> previousEpisode() async {
    if (!hasPrevious) return;
    await loadEpisode(_selectedIndex - 1);
  }

  void cycleScaleMode() {
    _scaleMode = _scaleMode.next;
    notifyListeners();
  }

  Future<void> _startPlayback(
    PlaybackInfo playback, {
    required int token,
  }) async {
    final controller = _videoController;
    if (controller == null) {
      throw StateError('Video controller missing');
    }
    if (token != _loadToken) {
      await controller.dispose();
      throw StateError('Playback request superseded');
    }

    await controller.setLooping(false);
    _restartTicker();
    await controller.play();
    _syncState(playback);
    _state = LoadState.success(playback);
    notifyListeners();
  }

  Future<
    ({
      PlaybackInfo playback,
      VideoPlayerController controller,
      int sourceIndex,
    })?
  >
  _preparePlayback({
    required int episodeIndex,
    required int sourceIndex,
    required bool allowSourceFallback,
  }) async {
    final episode = _episodes[episodeIndex];
    final availableSources = sourceChoices;
    final attemptOrder = <int>[];

    final clampedSource = availableSources.isNotEmpty
        ? sourceIndex.clamp(0, availableSources.length - 1)
        : 0;
    attemptOrder.add(clampedSource);

    if (allowSourceFallback && availableSources.isNotEmpty) {
      for (var i = 0; i < availableSources.length; i++) {
        if (!attemptOrder.contains(i)) {
          attemptOrder.add(i);
        }
      }
    }

    Object? lastError;
    for (final attemptSourceIndex in attemptOrder) {
      try {
        final playback = await _repository.resolvePlayback(
          episode.slug,
          server: attemptSourceIndex,
          allowFallback: allowSourceFallback,
        );
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(playback.streamUrl),
        );
        try {
          await controller.initialize().timeout(_initializeTimeout);
          return (
            playback: playback,
            controller: controller,
            sourceIndex: playback.server,
          );
        } catch (error) {
          lastError = error;
          await controller.dispose();
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      _error = lastError.toString();
    }
    return null;
  }

  void _syncState(PlaybackInfo playback) {
    final controller = _videoController;
    if (controller == null) return;
    _duration = controller.value.duration;
    _position = controller.value.position;
    _buffered = controller.value.buffered.isNotEmpty
        ? controller.value.buffered.last.end
        : Duration.zero;
    _state = LoadState.success(playback);
  }

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final controller = _videoController;
      if (controller == null) return;
      _duration = controller.value.duration;
      _position = controller.value.position;
      _buffered = controller.value.buffered.isNotEmpty
          ? controller.value.buffered.last.end
          : Duration.zero;
      notifyListeners();
    });
  }

  Future<void> _disposeVideoController() async {
    _ticker?.cancel();
    _ticker = null;
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _videoController?.dispose();
    super.dispose();
  }
}
