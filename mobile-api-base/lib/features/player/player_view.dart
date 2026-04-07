import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/widgets/tv_focusable.dart';
import '../../data/models/motchill_play_models.dart';
import 'frame_player.dart';
import 'playback_position_store.dart';
import 'player_controller.dart';

@visibleForTesting
Widget Function(PlaySource source)? debugBuildFramePlayerOverride;
@visibleForTesting
PlayerPlaybackController Function(PlaySource source)?
debugCreatePlaybackControllerOverride;

class PlayerPlaybackValue {
  const PlayerPlaybackValue({
    required this.isInitialized,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.size,
  });

  final bool isInitialized;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final Size size;

  PlayerPlaybackValue copyWith({
    bool? isInitialized,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    Size? size,
  }) {
    return PlayerPlaybackValue(
      isInitialized: isInitialized ?? this.isInitialized,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      size: size ?? this.size,
    );
  }
}

abstract class PlayerPlaybackController {
  PlayerPlaybackValue get value;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  Future<void> initialize();

  Future<void> setLooping(bool looping);

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setAudioTrack(PlayTrack? track);

  Future<void> setSubtitleTrack(PlayTrack? track);

  Future<void> dispose();

  Widget buildView();
}

class _MediaKitPlaybackController implements PlayerPlaybackController {
  _MediaKitPlaybackController(this._source)
    : _link = _source.link,
      _player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.error,
          bufferSize: 64 * 1024 * 1024,
        ),
      ) {
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );
  }

  final PlaySource _source;
  final String _link;
  final Player _player;
  late final VideoController _videoController;
  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Size _size = Size.zero;

  @override
  PlayerPlaybackValue get value {
    return PlayerPlaybackValue(
      isInitialized: _isInitialized,
      position: _position,
      duration: _duration,
      isPlaying: _isPlaying,
      size: _size,
    );
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  Widget buildView() {
    final aspectRatio = _size.width > 0 && _size.height > 0
        ? _size.width / _size.height
        : null;
    return Video(
      controller: _videoController,
      controls: NoVideoControls,
      fit: BoxFit.contain,
      aspectRatio: aspectRatio,
      fill: const Color(0xFF111111),
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 40),
        style: TextStyle(
          height: 1.25,
          fontSize: 24,
          letterSpacing: 0,
          wordSpacing: 0,
          color: Color(0xFFFFFFFF),
          fontWeight: FontWeight.normal,
          backgroundColor: Color(0xAA000000),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
  }

  @override
  Future<void> initialize() async {
    _attachStreamListeners();
    try {
      await _player.open(
        Media(
          _link,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (MotchillApiBase)',
            'Accept': 'application/x-mpegURL,application/vnd.apple.mpegurl,*/*',
            'Referer': 'https://motchilltv.taxi/',
            'Origin': 'https://motchilltv.taxi',
          },
        ),
        play: false,
      );
      await _applyInitialTracks();
      _isInitialized = true;
      _syncFromPlayer();
      _notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setAudioTrack(PlayTrack? track) async {
    if (track == null) {
      await _player.setAudioTrack(AudioTrack.auto());
    } else {
      await _player.setAudioTrack(
        AudioTrack.uri(
          track.file,
          title: track.displayLabel,
        ),
      );
    }
    _notifyListeners();
  }

  @override
  Future<void> setSubtitleTrack(PlayTrack? track) async {
    if (track == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(
          track.file,
          title: track.displayLabel,
        ),
      );
    }
    _notifyListeners();
  }

  @override
  Future<void> setLooping(bool looping) {
    return _player.setPlaylistMode(
      looping ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  void _attachStreamListeners() {
    if (_subscriptions.isNotEmpty) return;

    _subscriptions.add(
      _player.stream.position.listen((position) {
        _position = position;
        _notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        _duration = duration;
        _notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        _isPlaying = playing;
        _notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.width.listen((width) {
        _size = Size(width?.toDouble() ?? 0, _size.height);
        _notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.height.listen((height) {
        _size = Size(_size.width, height?.toDouble() ?? 0);
        _notifyListeners();
      }),
    );
  }

  void _syncFromPlayer() {
    final state = _player.state;
    _isPlaying = state.playing;
    _position = state.position;
    _duration = state.duration;
    _size = Size(state.width?.toDouble() ?? 0, state.height?.toDouble() ?? 0);
  }

  Future<void> _applyInitialTracks() async {
    await setAudioTrack(_source.defaultAudioTrack);
    await setSubtitleTrack(_source.defaultSubtitleTrack);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  final bool _isExpanded = true;

  PlayerController get controller => Get.find<PlayerController>();
  PlaybackPositionStore get positionStore =>
      Get.isRegistered<PlaybackPositionStore>()
      ? Get.find<PlaybackPositionStore>()
      : PlaybackPositionStore();

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      ),
    );
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _isExpanded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0F0F0F),
              foregroundColor: Colors.white,
              title: Text(
                controller.movieTitle.isNotEmpty
                    ? controller.movieTitle
                    : 'Episode player',
              ),
            ),
      body: SafeArea(
        top: !_isExpanded,
        bottom: true,
        child: _PlayerShell(
          controller: controller,
          positionStore: positionStore,
          isExpanded: _isExpanded,
          onToggleExpanded: () {},
        ),
      ),
    );
  }
}

class _PlayerShell extends StatelessWidget {
  const _PlayerShell({
    required this.controller,
    required this.positionStore,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final PlayerController controller;
  final PlaybackPositionStore positionStore;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.sources.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value != null && controller.sources.isEmpty) {
        return _ErrorState(
          message: controller.errorMessage.value!,
        );
      }

      final source = controller.selectedSource;
      if (source == null) {
        debugPrint('[Motchill.player] selected source is null');
        return const Center(
          child: Text(
            'No source available, try again later',
            style: TextStyle(color: Colors.white70),
          ),
        );
      }

      final playbackMode = _playbackModeFor(source);
      debugPrint(
        '[Motchill.player] render source mode=$playbackMode '
        'link=${source.link} frame=${source.isFrame} quality=${source.quality}',
      );

      return _PlayerLayout(
        controller: controller,
        positionStore: positionStore,
        sources: controller.sources.toList(growable: false),
        selectedIndex: controller.selectedIndex.value,
        source: source,
        playbackMode: playbackMode,
        isExpanded: isExpanded,
        onToggleExpanded: onToggleExpanded,
        onSelectSource: controller.selectSource,
      );
    });
  }
}

class _PlayerLayout extends StatelessWidget {
  const _PlayerLayout({
    required this.controller,
    required this.positionStore,
    required this.sources,
    required this.selectedIndex,
    required this.source,
    required this.playbackMode,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onSelectSource,
  });

  final PlayerController controller;
  final PlaybackPositionStore positionStore;
  final List<PlaySource> sources;
  final int selectedIndex;
  final PlaySource source;
  final _PlaybackMode playbackMode;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final void Function(int index) onSelectSource;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = EdgeInsets.fromLTRB(
          isExpanded ? 12 : 16,
          isExpanded ? 12 : 16,
          isExpanded ? 12 : 16,
          isExpanded ? 12 : 24,
        );
        final frameWidth = constraints.maxWidth - padding.horizontal;
        final frameHeight = isExpanded
            ? MediaQuery.sizeOf(context).height - padding.vertical
            : frameWidth * 9 / 16;

        return SingleChildScrollView(
          physics: isExpanded
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isExpanded) ...[
                  _PlayerHeader(
                    title: controller.movieTitle,
                    subtitle: controller.episodeLabel.isNotEmpty
                        ? controller.episodeLabel
                        : source.serverName,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  key: const ValueKey('player.surface'),
                  width: double.infinity,
                  height: frameHeight,
                  child: _PlayerFrame(
                    controller: controller,
                    movieId: controller.movieId,
                    episodeId: controller.episodeId,
                    positionStore: positionStore,
                    sources: sources,
                    selectedIndex: selectedIndex,
                    source: source,
                    playbackMode: playbackMode,
                    expanded: isExpanded,
                    onToggleExpanded: onToggleExpanded,
                    onSelectSource: onSelectSource,
                  ),
                ),
                if (!isExpanded) ...[
                  const SizedBox(height: 16),
                  if (controller.sources.length > 1) ...[
                    SizedBox(
                      key: const Key('player.sourceRail'),
                      height: 92,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = controller.sources[index];
                          return Obx(
                            () => _SourceChip(
                              source: item,
                              selected: controller.selectedIndex.value == index,
                              focusNode: FocusNode(
                                debugLabel: 'player.inline.source.$index',
                              ),
                              onKeyEvent: null,
                              autofocus: index == 0,
                              onTap: () => controller.selectSource(index),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemCount: controller.sources.length,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    key: const Key('player.secondaryInfo'),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      'Direct streams play inline. Embedded sources open inside the app.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.isNotEmpty ? title : 'Episode player',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    );
  }
}

class _PlayerFrame extends StatefulWidget {
  const _PlayerFrame({
    required this.controller,
    required this.movieId,
    required this.episodeId,
    required this.positionStore,
    required this.sources,
    required this.selectedIndex,
    required this.source,
    required this.playbackMode,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelectSource,
  });

  final PlayerController controller;
  final int movieId;
  final int episodeId;
  final PlaybackPositionStore positionStore;
  final List<PlaySource> sources;
  final int selectedIndex;
  final PlaySource source;
  final _PlaybackMode playbackMode;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(int index) onSelectSource;

  @override
  State<_PlayerFrame> createState() => _PlayerFrameState();
}

class _PlayerFrameState extends State<_PlayerFrame> {
  static const Duration _autoHideDuration = Duration(seconds: 3);
  static const Duration _timelineTick = Duration(milliseconds: 500);
  static const Duration _persistInterval = Duration(seconds: 5);

  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'player.shell');
  Timer? _autoHideTimer;
  Timer? _timelineTimer;
  Timer? _persistTimer;
  PlayerPlaybackController? _streamController;
  Future<void>? _streamInitializeFuture;
  Object? _streamInitError;
  Widget? _embeddedSurface;
  bool _controlsVisible = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _hasRestoredPosition = false;
  bool _hasMeaningfulPlaybackSnapshot = false;
  Duration _lastPersistedPosition = Duration.zero;
  Duration? _pendingRestorePosition;
  int _controlFocusEpoch = 0;
  PlayTrack? _selectedAudioTrack;
  PlayTrack? _selectedSubtitleTrack;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'player.backButton');
  final GlobalKey<_ProgressBarRowState> _progressRowKey =
      GlobalKey<_ProgressBarRowState>();

  int get movieId => widget.movieId;
  int get episodeId => widget.episodeId;
  PlayerController get controller => widget.controller;
  PlaybackPositionStore get positionStore => widget.positionStore;
  List<PlaySource> get sources => widget.sources;
  int get selectedIndex => widget.selectedIndex;
  PlaySource get source => widget.source;
  _PlaybackMode get playbackMode => widget.playbackMode;
  bool get expanded => widget.expanded;
  VoidCallback get onToggleExpanded => widget.onToggleExpanded;
  void Function(int index) get onSelectSource => widget.onSelectSource;

  @override
  void initState() {
    super.initState();
    _embeddedSurface = _buildEmbeddedSurface();
    _resetTrackSelections();
    _setupStreamController();
    _scheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant _PlayerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.link != widget.source.link) {
      _embeddedSurface = _buildEmbeddedSurface();
      unawaited(_persistPosition());
      _controlsVisible = true;
      _hasRestoredPosition = false;
      _lastPersistedPosition = _position;
      _resetTrackSelections();
      _setupStreamController();
      _scheduleAutoHide();
      return;
    }

    if (oldWidget.expanded != widget.expanded) {
      _controlsVisible = true;
      _scheduleAutoHide();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _timelineTimer?.cancel();
    _persistTimer?.cancel();
    unawaited(_persistPosition());
    _streamController?.removeListener(_syncStreamState);
    unawaited(_streamController?.dispose() ?? Future<void>.value());
    _backFocusNode.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  bool _isActivateKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleBackKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    return handlePlayerBackKey(
      event.logicalKey,
      onBack: () => Get.back<void>(),
      onFocusSource0: () => _progressRowKey.currentState?._focusSource(0),
    );
  }

  void _setupStreamController() {
    _timelineTimer?.cancel();
    _persistTimer?.cancel();
    _streamController?.removeListener(_syncStreamState);
    unawaited(_streamController?.dispose() ?? Future<void>.value());
    _streamController = null;
    _streamInitializeFuture = null;
    _streamInitError = null;
    if (_position == Duration.zero) {
      _duration = Duration.zero;
      _isPlaying = false;
    }

    if (playbackMode != _PlaybackMode.stream) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final controller =
        debugCreatePlaybackControllerOverride?.call(source) ??
        _MediaKitPlaybackController(source);
    _streamController = controller;
    _streamInitializeFuture = _setupStreamFuture(controller);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setupStreamFuture(PlayerPlaybackController controller) async {
    try {
      controller.addListener(_syncStreamState);
      await controller.initialize();
      await controller.setLooping(false);
      await _restorePositionIfNeeded();
      await _applyTrackSelections(controller);
      await controller.play();
      await _applyPendingRestoreIfNeeded(controller);
      _syncStreamState();
      _timelineTimer?.cancel();
      _timelineTimer = Timer.periodic(_timelineTick, (_) {
        if (!mounted || _streamController != controller) return;
        _syncStreamState();
      });
      _persistTimer?.cancel();
      _persistTimer = Timer.periodic(_persistInterval, (_) {
        if (_streamController != controller) return;
        unawaited(_persistPosition());
      });
    } catch (error) {
      _streamInitError = error;
      rethrow;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _syncStreamState() {
    if (!mounted) return;
    final controller = _streamController;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;
    if (_pendingRestorePosition != null &&
        value.duration == Duration.zero &&
        value.position == Duration.zero) {
      return;
    }
    if (_pendingRestorePosition != null && value.duration > Duration.zero) {
      unawaited(_applyPendingRestoreIfNeeded(controller));
      return;
    }
    final nextPosition = value.position;
    final nextDuration = value.duration;
    final nextPlaying = value.isPlaying;
    if (nextPosition > Duration.zero) {
      _hasMeaningfulPlaybackSnapshot = true;
    }

    if (nextPosition == _position &&
        nextDuration == _duration &&
        nextPlaying == _isPlaying) {
      return;
    }

    setState(() {
      _position = nextPosition;
      _duration = nextDuration;
      _isPlaying = nextPlaying;
    });

    _maybePersistPosition();
  }

  void _resetTrackSelections() {
    _selectedAudioTrack = source.defaultAudioTrack;
    _selectedSubtitleTrack = source.defaultSubtitleTrack;
  }

  Future<void> _togglePlayback() async {
    final controller = _streamController;
    if (controller == null || !controller.value.isInitialized) return;
    final nextPlaying = !controller.value.isPlaying;
    if (mounted) {
      setState(() {
        _isPlaying = nextPlaying;
      });
    }
    if (nextPlaying) {
      await controller.play();
    } else {
      await controller.pause();
      await _persistPosition();
    }
    _syncStreamState();
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _streamController;
    if (controller == null || !controller.value.isInitialized) return;
    final maxPosition = _duration == Duration.zero ? position : _duration;
    final clampedMilliseconds = position.inMilliseconds.clamp(
      0,
      maxPosition.inMilliseconds,
    );
    final target = Duration(milliseconds: clampedMilliseconds);
    await controller.seekTo(target);
    _syncStreamState();
  }

  Future<void> _seekBy(Duration offset) async {
    await _seekTo(_position + offset);
  }

  Future<void> _restorePositionIfNeeded() async {
    if (_hasRestoredPosition) return;

    final savedPosition = _position > Duration.zero
        ? _position
        : await positionStore.load(movieId, episodeId);
    if (savedPosition == null || savedPosition <= Duration.zero) {
      _hasRestoredPosition = true;
      return;
    }

    _markPendingRestore(savedPosition);
  }

  Future<void> _applyPendingRestoreIfNeeded(
    PlayerPlaybackController controller,
  ) async {
    final target = _pendingRestorePosition;
    if (target == null) return;
    if (!controller.value.isInitialized) return;
    if (controller.value.duration == Duration.zero) return;

    _pendingRestorePosition = null;
    await controller.seekTo(target);
    _position = target;
    _lastPersistedPosition = target;
    _hasMeaningfulPlaybackSnapshot = true;
    _syncStreamState();
  }

  void _markPendingRestore(Duration savedPosition) {
    _pendingRestorePosition = savedPosition;
    _position = savedPosition;
    _lastPersistedPosition = savedPosition;
    _hasMeaningfulPlaybackSnapshot = true;
    _hasRestoredPosition = true;
  }

  Future<void> _persistPosition() async {
    if (playbackMode != _PlaybackMode.stream) return;

    final controller = _streamController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;
    _position = value.position;
    _duration = value.duration;
    _isPlaying = value.isPlaying;
    if (_position > Duration.zero) {
      _hasMeaningfulPlaybackSnapshot = true;
    }

    if (!_hasMeaningfulPlaybackSnapshot || _position < Duration.zero) return;
    await positionStore.save(movieId, episodeId, _position);
    _lastPersistedPosition = _position;
  }

  Future<void> _applyTrackSelections(
    PlayerPlaybackController controller,
  ) async {
    if (source.hasAudioTracks) {
      await controller.setAudioTrack(_selectedAudioTrack);
    }
    if (source.hasSubtitleTracks) {
      await controller.setSubtitleTrack(_selectedSubtitleTrack);
    }
  }

  void _maybePersistPosition() {
    if (playbackMode != _PlaybackMode.stream) return;
    if (_position <= Duration.zero) return;
    if (_position - _lastPersistedPosition < const Duration(seconds: 1)) {
      return;
    }
    unawaited(_persistPosition());
  }

  Future<void> _handleSelectSource(int index) async {
    if (index < 0 || index >= sources.length) return;
    if (index == selectedIndex) return;
    _showControls();
    await _persistPosition();
    onSelectSource(index);
  }

  Future<void> _handleSelectAudioTrack(PlayTrack? track) async {
    _selectedAudioTrack = track;
    final controller = _streamController;
    if (controller == null) return;
    await controller.setAudioTrack(track);
  }

  Future<void> _handleSelectSubtitleTrack(PlayTrack? track) async {
    _selectedSubtitleTrack = track;
    final controller = _streamController;
    if (controller == null) return;
    await controller.setSubtitleTrack(track);
  }

  Widget _buildEmbeddedSurface() {
    return debugBuildFramePlayerOverride?.call(source) ?? buildFramePlayer(source);
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDuration, () {
      if (!mounted) return;
      setState(() {
        _controlsVisible = false;
      });
      _playerFocusNode.requestFocus();
    });
  }

  void _showControls() {
    final wasHidden = !_controlsVisible;
    if (wasHidden) {
      setState(() {
        _controlsVisible = true;
        _controlFocusEpoch += 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controlsVisible) return;
        _progressRowKey.currentState?._focusPlayPause();
      });
    } else {
      _scheduleAutoHide();
      return;
    }
    _scheduleAutoHide();
  }

  void _hideControls() {
    _autoHideTimer?.cancel();
    if (_controlsVisible) {
      setState(() {
        _controlsVisible = false;
      });
    }
    _playerFocusNode.requestFocus();
  }

  void _toggleControlsVisibility() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = ClipRRect(
      borderRadius: BorderRadius.circular(expanded ? 28 : 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: playbackMode == _PlaybackMode.webView
            ? KeyedSubtree(
                key: ValueKey(source.link),
                child: _embeddedSurface ?? _buildEmbeddedSurface(),
              )
            : playbackMode == _PlaybackMode.stream
            ? _StreamPlayerSurface(
                key: ValueKey(source.link),
                controller: _streamController,
                initializeFuture: _streamInitializeFuture,
                initError: _streamInitError,
              )
            : _UnsupportedPlayer(
                key: ValueKey(source.link),
                source: source,
                mode: playbackMode,
              ),
      ),
    );

    final player = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: frame),
        Positioned.fill(
          child: GestureDetector(
            key: const Key('player.surfaceTapTarget'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControlsVisibility,
            child: const SizedBox.expand(),
          ),
        ),
        _PlayerChrome(
          source: source,
          sources: sources,
          selectedIndex: selectedIndex,
          focusEpoch: _controlFocusEpoch,
          expanded: expanded,
          visible: _controlsVisible,
          onBack: () => Get.back<void>(),
          onShowControls: _showControls,
          backFocusNode: _backFocusNode,
          backOnKeyEvent: _handleBackKey,
          progressRowKey: _progressRowKey,
          onSelectSource: (index) => unawaited(_handleSelectSource(index)),
          onSelectAudioTrack: _handleSelectAudioTrack,
          onSelectSubtitleTrack: _handleSelectSubtitleTrack,
          selectedAudioTrack: _selectedAudioTrack,
          selectedSubtitleTrack: _selectedSubtitleTrack,
          onTogglePlayback: _togglePlayback,
          onSeekBackward: () =>
              unawaited(_seekBy(const Duration(seconds: -10))),
          onSeekForward: () => unawaited(_seekBy(const Duration(seconds: 10))),
          onSeekTo: _seekTo,
          position: _position,
          duration: _duration,
          isPlaying: _isPlaying,
        ),
      ],
    );

    return Focus(
      focusNode: _playerFocusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _showControls();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: player,
    );
  }
}

KeyEventResult handlePlayerBackKey(
  LogicalKeyboardKey logicalKey, {
  required VoidCallback onBack,
  required VoidCallback onFocusSource0,
}) {
  final isActivateKey = logicalKey == LogicalKeyboardKey.enter ||
      logicalKey == LogicalKeyboardKey.select ||
      logicalKey == LogicalKeyboardKey.space;
  if (isActivateKey) {
    onBack();
    return KeyEventResult.handled;
  }

  if (logicalKey == LogicalKeyboardKey.arrowDown) {
    onFocusSource0();
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({
    required this.source,
    required this.sources,
    required this.selectedIndex,
    required this.focusEpoch,
    required this.expanded,
    required this.visible,
    required this.onBack,
    required this.onShowControls,
    required this.backFocusNode,
    required this.backOnKeyEvent,
    required this.progressRowKey,
    required this.onSelectSource,
    required this.onSelectAudioTrack,
    required this.onSelectSubtitleTrack,
    required this.selectedAudioTrack,
    required this.selectedSubtitleTrack,
    required this.onTogglePlayback,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onSeekTo,
    required this.position,
    required this.duration,
    required this.isPlaying,
  });

  final PlaySource source;
  final List<PlaySource> sources;
  final int selectedIndex;
  final int focusEpoch;
  final bool expanded;
  final bool visible;
  final VoidCallback onBack;
  final VoidCallback onShowControls;
  final FocusNode backFocusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event) backOnKeyEvent;
  final GlobalKey<_ProgressBarRowState> progressRowKey;
  final void Function(int index) onSelectSource;
  final Future<void> Function(PlayTrack? track) onSelectAudioTrack;
  final Future<void> Function(PlayTrack? track) onSelectSubtitleTrack;
  final PlayTrack? selectedAudioTrack;
  final PlayTrack? selectedSubtitleTrack;
  final Future<void> Function() onTogglePlayback;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final Future<void> Function(Duration position) onSeekTo;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  @override
  Widget build(BuildContext context) {
    final chrome = Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: TvFocusable(
            key: const Key('player.backButton'),
            focusNode: backFocusNode,
            onTap: onBack,
            onKeyEvent: backOnKeyEvent,
            borderRadius: BorderRadius.circular(999),
            focusedBorderColor: const Color(0xFFFFD15C),
            focusedBackgroundColor: Colors.black.withValues(alpha: 0.6),
            scrollOnFocus: false,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: _ProgressBarRow(
            key: progressRowKey,
            source: source,
            sources: sources,
            selectedIndex: selectedIndex,
            focusEpoch: focusEpoch,
            position: position,
            duration: duration,
            onSeekTo: onSeekTo,
            onTapAnyControl: onShowControls,
            onSelectSource: onSelectSource,
            onSelectAudioTrack: onSelectAudioTrack,
            onSelectSubtitleTrack: onSelectSubtitleTrack,
            selectedAudioTrack: selectedAudioTrack,
            selectedSubtitleTrack: selectedSubtitleTrack,
            onSeekBackward: onSeekBackward,
            onSeekForward: onSeekForward,
            onTogglePlayback: onTogglePlayback,
            isPlaying: isPlaying,
            onFocusBackButton: () => backFocusNode.requestFocus(),
          ),
        ),
      ],
    );

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: visible
            ? IgnorePointer(
                key: const ValueKey('player.chrome.visible'),
                ignoring: false,
                child: chrome,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ProgressBarRow extends StatefulWidget {
  const _ProgressBarRow({
    super.key,
    required this.source,
    required this.sources,
    required this.selectedIndex,
    required this.focusEpoch,
    required this.position,
    required this.duration,
    required this.onSeekTo,
    required this.onTapAnyControl,
    required this.onSelectSource,
    required this.onSelectAudioTrack,
    required this.onSelectSubtitleTrack,
    required this.selectedAudioTrack,
    required this.selectedSubtitleTrack,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onTogglePlayback,
    required this.isPlaying,
    required this.onFocusBackButton,
  });

  final PlaySource source;
  final List<PlaySource> sources;
  final int selectedIndex;
  final int focusEpoch;
  final Duration position;
  final Duration duration;
  final Future<void> Function(Duration position) onSeekTo;
  final VoidCallback onTapAnyControl;
  final void Function(int index) onSelectSource;
  final Future<void> Function(PlayTrack? track) onSelectAudioTrack;
  final Future<void> Function(PlayTrack? track) onSelectSubtitleTrack;
  final PlayTrack? selectedAudioTrack;
  final PlayTrack? selectedSubtitleTrack;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final Future<void> Function() onTogglePlayback;
  final bool isPlaying;
  final VoidCallback onFocusBackButton;

  @override
  State<_ProgressBarRow> createState() => _ProgressBarRowState();
}

class _ProgressBarRowState extends State<_ProgressBarRow> {
  final FocusScopeNode _controlsScopeNode = FocusScopeNode(
    debugLabel: 'player.controlsScope',
  );
  late List<FocusNode> _sourceFocusNodes;
  late final FocusNode _progressFocusNode = FocusNode(
    debugLabel: 'player.progress',
  );
  late final List<FocusNode> _transportFocusNodes = <FocusNode>[
    FocusNode(debugLabel: 'player.seekBack10'),
    FocusNode(debugLabel: 'player.playPause'),
    FocusNode(debugLabel: 'player.seekForward10'),
  ];
  bool _progressFocused = false;

  @override
  void initState() {
    super.initState();
    _sourceFocusNodes = _buildSourceFocusNodes(widget.sources.length);
  }

  @override
  void didUpdateWidget(covariant _ProgressBarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sources.length != widget.sources.length) {
      for (final node in _sourceFocusNodes) {
        node.dispose();
      }
      _sourceFocusNodes = _buildSourceFocusNodes(widget.sources.length);
    }

  }

  @override
  void dispose() {
    for (final node in _sourceFocusNodes) {
      node.dispose();
    }
    _progressFocusNode.dispose();
    for (final node in _transportFocusNodes) {
      node.dispose();
    }
    _controlsScopeNode.dispose();
    super.dispose();
  }

  List<FocusNode> _buildSourceFocusNodes(int count) {
    return List<FocusNode>.generate(
      count,
      (index) => FocusNode(debugLabel: 'player.source.$index'),
    );
  }

  void _focusSource(int index) {
    if (index < 0 || index >= _sourceFocusNodes.length) return;
    _sourceFocusNodes[index].requestFocus();
  }

  void _focusProgress() {
    _progressFocusNode.requestFocus();
  }

  void _focusTransport(int index) {
    if (index < 0 || index >= _transportFocusNodes.length) return;
    _transportFocusNodes[index].requestFocus();
  }

  void _focusPlayPause() {
    _focusTransport(1);
  }

  bool _isActivateKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space;
  }

  Duration _seekStep() {
    final totalMilliseconds = widget.duration.inMilliseconds;
    if (totalMilliseconds <= 0) {
      return const Duration(seconds: 10);
    }

    final scaled = (totalMilliseconds * 0.03).round();
    final clamped = scaled.clamp(5000, 30000);
    return Duration(milliseconds: clamped);
  }

  Future<void> _seekBy(Duration offset) async {
    final target = widget.position + offset;
    final maxPosition = widget.duration == Duration.zero
        ? target
        : widget.duration;
    final clampedMilliseconds = target.inMilliseconds.clamp(
      0,
      maxPosition.inMilliseconds,
    );
    await widget.onSeekTo(Duration(milliseconds: clampedMilliseconds));
  }

  void _selectSource(int index) {
    widget.onTapAnyControl();
    widget.onSelectSource(index);
    _focusSource(index);
  }

  void _activateSource(int index) {
    _selectSource(index);
  }

  void _activateTransport(int index) {
    widget.onTapAnyControl();
    switch (index) {
      case 0:
        widget.onSeekBackward();
      case 1:
        unawaited(widget.onTogglePlayback());
      case 2:
        widget.onSeekForward();
    }
  }

  KeyEventResult _handleSourceKey(
    int index,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isActivateKey(event)) {
      _activateSource(index);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        widget.onTapAnyControl();
        _focusSource(index - 1);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < _sourceFocusNodes.length - 1) {
        widget.onTapAnyControl();
        _focusSource(index + 1);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onTapAnyControl();
      _focusProgress();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onFocusBackButton();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleProgressKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isActivateKey(event)) {
      widget.onTapAnyControl();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onTapAnyControl();
      unawaited(_seekBy(-_seekStep()));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onTapAnyControl();
      unawaited(_seekBy(_seekStep()));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onTapAnyControl();
      _focusSource(0);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onTapAnyControl();
      _focusTransport(0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTransportKey(
    int index,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isActivateKey(event)) {
      _activateTransport(index);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) _focusTransport(index - 1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < _transportFocusNodes.length - 1) {
        _focusTransport(index + 1);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onTapAnyControl();
      _focusProgress();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final totalMilliseconds = widget.duration.inMilliseconds;
    final currentMilliseconds = widget.position.inMilliseconds.clamp(
      0,
      totalMilliseconds > 0
          ? totalMilliseconds
          : widget.position.inMilliseconds,
    );
    final progress = totalMilliseconds > 0
        ? currentMilliseconds / totalMilliseconds
        : 0.0;

    return FocusScope(
      node: _controlsScopeNode,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          key: const Key('player.progressRow'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.sources.isNotEmpty) ...[
                _SourceRail(
                  sources: widget.sources,
                  selectedIndex: widget.selectedIndex,
                  focusNodes: _sourceFocusNodes,
                  autofocusFirstSource: widget.focusEpoch == 0,
                  onKeyEvent: _handleSourceKey,
                  onSelectSource: _selectSource,
                ),
                const SizedBox(height: 10),
              ],
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => widget.onTapAnyControl(),
                child: Focus(
                  focusNode: _progressFocusNode,
                  onFocusChange: (focused) {
                    if (!mounted) return;
                    setState(() {
                      _progressFocused = focused;
                    });
                  },
                  onKeyEvent: _handleProgressKey,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: _progressFocused ? 0.06 : 0.03,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _progressFocused
                            ? const Color(0xFFE8A7A7)
                            : Colors.white.withValues(alpha: 0.12),
                        width: _progressFocused ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(widget.position),
                          key: const Key('player.currentTime'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: const Color(0xFFE8A7A7),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFE8A7A7),
                            ),
                            child: Slider(
                              key: const Key('player.progressSlider'),
                              value: progress.clamp(0.0, 1.0),
                              onChangeStart: (_) => widget.onTapAnyControl(),
                              onChanged: (value) {
                                final next = Duration(
                                  milliseconds:
                                      (totalMilliseconds * value).round(),
                                );
                                unawaited(widget.onSeekTo(next));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatDuration(widget.duration),
                          key: const Key('player.totalTime'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (widget.source.hasAudioTracks)
                            _TrackIconMenuButton(
                              key: const Key('player.audioTrackButton'),
                              icon: Icons.audiotrack_rounded,
                              tooltip: 'Audio',
                              isActive: widget.selectedAudioTrack != null,
                              defaultLabel: 'Auto',
                              options: widget.source.audioTracks
                                  .toList(growable: false),
                              onSelected: (track) {
                                widget.onTapAnyControl();
                                return widget.onSelectAudioTrack(track);
                              },
                            ),
                          if (widget.source.hasSubtitleTracks)
                            _TrackIconMenuButton(
                              key: const Key('player.subtitleTrackButton'),
                              icon: Icons.closed_caption_rounded,
                              tooltip: 'Subtitle',
                              isActive: widget.selectedSubtitleTrack != null,
                              defaultLabel: 'Off',
                              options: widget.source.subtitleTracks
                                  .toList(growable: false),
                              onSelected: (track) {
                                widget.onTapAnyControl();
                                return widget.onSelectSubtitleTrack(track);
                              },
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniTransportButton(
                          key: const Key('player.seekBack10'),
                          icon: Icons.replay_10_rounded,
                          focusNode: _transportFocusNodes[0],
                          onKeyEvent: (node, event) =>
                              _handleTransportKey(0, node, event),
                          onTap: () => _activateTransport(0),
                        ),
                        const SizedBox(width: 14),
                        _PlayButton(
                          key: const Key('player.playPause'),
                          icon: widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          focusNode: _transportFocusNodes[1],
                          autofocus: false,
                          onKeyEvent: (node, event) =>
                              _handleTransportKey(1, node, event),
                          onTap: () => _activateTransport(1),
                        ),
                        const SizedBox(width: 14),
                        _MiniTransportButton(
                          key: const Key('player.seekForward10'),
                          icon: Icons.forward_10_rounded,
                          focusNode: _transportFocusNodes[2],
                          onKeyEvent: (node, event) =>
                              _handleTransportKey(2, node, event),
                          onTap: () => _activateTransport(2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRail extends StatelessWidget {
  const _SourceRail({
    required this.sources,
    required this.selectedIndex,
    required this.onSelectSource,
    required this.focusNodes,
    required this.onKeyEvent,
    required this.autofocusFirstSource,
  });

  final List<PlaySource> sources;
  final int selectedIndex;
  final void Function(int index) onSelectSource;
  final List<FocusNode> focusNodes;
  final bool autofocusFirstSource;
  final KeyEventResult Function(int index, FocusNode node, KeyEvent event)
  onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('player.sourceRailInline'),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          final source = sources[index];
          return _SourceChip(
            key: Key('player.sourceChip.${source.sourceId}'),
            source: source,
            selected: index == selectedIndex,
            focusNode: focusNodes[index],
            onKeyEvent: (node, event) => onKeyEvent(index, node, event),
            onTap: () => onSelectSource(index),
            autofocus: autofocusFirstSource && index == 0,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: sources.length,
      ),
    );
  }
}

class _TrackIconMenuButton extends StatelessWidget {
  const _TrackIconMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.defaultLabel,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final String defaultLabel;
  final List<PlayTrack> options;
  final Future<void> Function(PlayTrack? track) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: tooltip,
      color: const Color(0xFF151515),
      offset: const Offset(0, 40),
      onSelected: (index) {
        final track = index == 0 ? null : options[index - 1];
        unawaited(onSelected(track));
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<int>>[
          PopupMenuItem<int>(
            value: 0,
            child: Text(
              defaultLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          ...options.asMap().entries.map(
                (entry) => PopupMenuItem<int>(
                  value: entry.key + 1,
                  child: Text(
                    entry.value.displayLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
        ];
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2A1A1A)
              : Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFFE8A7A7)
                : Colors.white.withValues(alpha: 0.14),
            width: isActive ? 1.2 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFE8A7A7) : Colors.white70,
          size: 18,
        ),
      ),
    );
  }
}


String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minutesPart = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}'
      : '$minutes';
  return '$minutesPart:${seconds.toString().padLeft(2, '0')}';
}

class _MiniTransportButton extends StatelessWidget {
  const _MiniTransportButton({
    super.key,
    required this.icon,
    required this.focusNode,
    this.autofocus = false,
    required this.onKeyEvent,
    required this.onTap,
  });

  final IconData icon;
  final FocusNode focusNode;
  final bool autofocus;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CircularControl(
      diameter: 52,
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: onKeyEvent,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    super.key,
    required this.icon,
    required this.focusNode,
    required this.autofocus,
    required this.onKeyEvent,
    required this.onTap,
  });

  final IconData icon;
  final FocusNode focusNode;
  final bool autofocus;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CircularControl(
      diameter: 68,
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: onKeyEvent,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 34),
    );
  }
}

class _CircularControl extends StatelessWidget {
  const _CircularControl({
    required this.diameter,
    required this.focusNode,
    required this.autofocus,
    required this.onKeyEvent,
    required this.onTap,
    required this.child,
  });

  final double diameter;
  final FocusNode focusNode;
  final bool autofocus;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(diameter / 2),
      focusedBorderColor: const Color(0xFFFFD15C),
      focusedBackgroundColor: Colors.black.withValues(alpha: 0.58),
      scrollOnFocus: false,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

enum _PlaybackMode { stream, webView, unsupported }

_PlaybackMode _playbackModeFor(PlaySource source) {
  if (source.isFrame) {
    return defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? _PlaybackMode.webView
        : _PlaybackMode.unsupported;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? _PlaybackMode.stream
      : _PlaybackMode.unsupported;
}

class _StreamPlayerSurface extends StatelessWidget {
  const _StreamPlayerSurface({
    super.key,
    required this.controller,
    required this.initializeFuture,
    required this.initError,
  });

  final PlayerPlaybackController? controller;
  final Future<void>? initializeFuture;
  final Object? initError;

  @override
  Widget build(BuildContext context) {
    final localController = controller;
    if (localController == null || initializeFuture == null) {
      return const ColoredBox(
        color: Color(0xFF111111),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError || initError != null) {
          return ColoredBox(
            color: const Color(0xFF111111),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Video player error:\n${snapshot.error ?? initError}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !localController.value.isInitialized) {
          return const ColoredBox(
            color: Color(0xFF111111),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return ColoredBox(
          color: const Color(0xFF111111),
          child: SizedBox.expand(child: localController.buildView()),
        );
      },
    );
  }
}

class _UnsupportedPlayer extends StatelessWidget {
  const _UnsupportedPlayer({
    super.key,
    required this.source,
    required this.mode,
  });

  final PlaySource source;
  final _PlaybackMode mode;

  @override
  Widget build(BuildContext context) {
    final reason = switch (mode) {
      _PlaybackMode.stream =>
        'Direct stream playback is not supported on this platform.',
      _PlaybackMode.webView =>
        'Embedded player playback is shown inside the app.',
      _PlaybackMode.unsupported =>
        'This playback mode is not supported on this platform.',
    };

    debugPrint(
      '[Motchill.player] unsupported playback mode=$mode link=${source.link}',
    );

    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              source.link,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE7B5B5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    super.key,
    required this.source,
    required this.selected,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onTap,
    this.autofocus = false,
  });

  final PlaySource source;
  final bool selected;
  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(12),
      focusedBorderColor: const Color(0xFFFFD15C),
      focusedBackgroundColor: Colors.white.withValues(alpha: 0.06),
      scrollOnFocus: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 112,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2A1A1A)
              : Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFE8A7A7)
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          source.serverName.isNotEmpty ? source.serverName : 'Source',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white54,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
