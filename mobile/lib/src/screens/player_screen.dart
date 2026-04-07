import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../data/motchill_repository.dart';
import '../features/player/player_controller.dart';
import '../features/shared/load_state.dart';
import '../models.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.repository,
    required this.detail,
    this.initialIndex = 0,
  });

  final MotchillRepository repository;
  final MovieDetail detail;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerController _controller;
  Timer? _controlsTimer;
  bool _controlsVisible = true;
  bool _dragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller = PlayerController(
      repository: widget.repository,
      detail: widget.detail,
      initialIndex: widget.initialIndex,
    )..loadSelectedEpisode();
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.dispose();
    super.dispose();
  }

  void _showControls({bool restartTimer = true}) {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    if (restartTimer) {
      _scheduleHideControls();
    }
  }

  void _hideControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = false);
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _scheduleHideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), _hideControls);
  }

  Future<bool> _onSourceSelected(int index) async {
    _showControls();
    final success = await _controller.selectSource(index);
    if (!mounted) return false;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source unavailable, please choose another one.'),
        ),
      );
    }
    return success;
  }

  Future<void> _onScalePressed() async {
    _showControls();
    _controller.cycleScaleMode();
  }

  Future<void> _onPlayPausePressed() async {
    _showControls();
    await _controller.togglePlayPause();
  }

  Future<void> _onSeek(Duration position) async {
    _showControls();
    await _controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final videoController = _controller.videoController;
        final currentEpisode = _controller.currentEpisode;
        final sourceChoices = _controller.sourceChoices;
        final currentSource = _controller.currentSource;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildBody(context, state, videoController),
                  ),
                  if (_controlsVisible)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopBar(
                        title: widget.detail.title,
                        subtitle:
                            '${currentEpisode.label} • ${currentSource.label}',
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  if (_controlsVisible &&
                      state.status == LoadStatus.success &&
                      videoController != null &&
                      videoController.value.isInitialized)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ControlsPanel(
                        controller: _controller,
                        sourceChoices: sourceChoices,
                        isDragging: _dragging,
                        dragValue: _dragValue,
                        onSourceSelected: _onSourceSelected,
                        onScalePressed: _onScalePressed,
                        onPlayPausePressed: _onPlayPausePressed,
                        onSeekStart: () => setState(() => _dragging = true),
                        onSeekEnd: () => setState(() => _dragging = false),
                        onSeekChanged: (value) {
                          setState(() {
                            _dragValue = value;
                          });
                          _onSeek(Duration(milliseconds: value.round()));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    LoadState<PlaybackInfo> state,
    VideoPlayerController? controller,
  ) {
    if (state.status == LoadStatus.loading && controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == LoadStatus.failure) {
      return _PlayerError(
        message: _controller.error ?? state.error.toString(),
        onRetry: () => _controller.loadEpisode(_controller.selectedIndex),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildVideoSurface(controller, state.value);
  }

  Widget _buildVideoSurface(
    VideoPlayerController controller,
    PlaybackInfo? playback,
  ) {
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16.0;
    final height = size.height > 0 ? size.height : 9.0;
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : width / height;

    final frame = Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(controller),
        if (playback != null)
          Positioned(
            left: 16,
            bottom: 16,
            child: _PlaybackTag(text: playback.playbackKind.toUpperCase()),
          ),
      ],
    );

    final scaledFrame = switch (_controller.scaleMode) {
      PlayerScaleMode.contain => Center(
        child: AspectRatio(aspectRatio: aspectRatio, child: frame),
      ),
      PlayerScaleMode.zoom => ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(width: width, height: height, child: frame),
        ),
      ),
      PlayerScaleMode.fill => ClipRect(
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.center,
          child: SizedBox(width: width, height: height, child: frame),
        ),
      ),
    };

    return SizedBox.expand(child: scaledFrame);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.controller,
    required this.sourceChoices,
    required this.isDragging,
    required this.dragValue,
    required this.onSourceSelected,
    required this.onScalePressed,
    required this.onPlayPausePressed,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onSeekChanged,
  });

  final PlayerController controller;
  final List<PlaybackSourceChoice> sourceChoices;
  final bool isDragging;
  final double dragValue;
  final Future<bool> Function(int index) onSourceSelected;
  final Future<void> Function() onScalePressed;
  final Future<void> Function() onPlayPausePressed;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  final ValueChanged<double> onSeekChanged;

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final duration = controller.duration.inMilliseconds > 0
        ? controller.duration
        : const Duration(seconds: 1);
    final current = isDragging
        ? Duration(milliseconds: dragValue.round())
        : controller.position;
    final position = current.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final buffered = controller.buffered.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.84),
            Colors.black.withValues(alpha: 0.52),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 42,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final source in sourceChoices) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected:
                            source.index == controller.selectedSourceIndex,
                        avatar: source.available
                            ? null
                            : const Icon(Icons.block_rounded, size: 16),
                        label: Text(source.label),
                        labelStyle: TextStyle(
                          color: source.available
                              ? null
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        onSelected: (_) => onSourceSelected(source.index),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: onScalePressed,
                      icon: const Icon(Icons.aspect_ratio_rounded, size: 18),
                      label: Text(controller.scaleMode.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
              activeTrackColor: const Color(0xFF32D6B7),
              thumbColor: const Color(0xFF32D6B7),
            ),
            child: Slider(
              value: position,
              min: 0,
              max: duration.inMilliseconds.toDouble(),
              secondaryTrackValue: buffered,
              onChangeStart: (_) => onSeekStart(),
              onChangeEnd: (_) => onSeekEnd(),
              onChanged: onSeekChanged,
            ),
          ),
          Row(
            children: [
              Text(_format(current)),
              const Spacer(),
              Text(_format(controller.duration)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: controller.hasPrevious
                    ? controller.previousEpisode
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton(
                onPressed: () => controller.seekTo(
                  controller.position - const Duration(seconds: 10),
                ),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onPlayPausePressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: Icon(
                  controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 28,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => controller.seekTo(
                  controller.position + const Duration(seconds: 10),
                ),
                icon: const Icon(Icons.forward_10_rounded),
              ),
              IconButton(
                onPressed: controller.hasNext ? controller.nextEpisode : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: controller.hasPrevious
                    ? controller.previousEpisode
                    : null,
                icon: const Icon(Icons.skip_previous_rounded, size: 18),
                label: const Text('Prev'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: controller.hasNext ? controller.nextEpisode : null,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Next'),
              ),
              const Spacer(),
              Text(
                '${controller.selectedIndex + 1}/${controller.episodes.length}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaybackTag extends StatelessWidget {
  const _PlaybackTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Playback failed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
