import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/models/motchill_play_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/features/player/player_controller.dart';
import 'package:mobile_api_base/features/player/player_view.dart';

class _FakeRepository extends MotchillRepository {
  _FakeRepository() : super(apiClient: _FakeApiClient());

  @override
  Future<List<PlaySource>> loadEpisodeSources({
    required int movieId,
    required int episodeId,
    int server = 0,
  }) async {
    return [
      const PlaySource(
        sourceId: 1,
        serverName: 'Server 1',
        link: 'https://example.com/stream-1.m3u8',
        subtitle: '',
        type: 0,
        isFrame: false,
        quality: '1080p',
        tracks: [
          PlayTrack(
            kind: 'audio',
            file: 'https://example.com/audio-en.m3u8',
            label: 'English',
            isDefault: true,
          ),
          PlayTrack(
            kind: 'subtitle',
            file: 'https://example.com/sub-en.vtt',
            label: 'English CC',
            isDefault: true,
          ),
        ],
      ),
      const PlaySource(
        sourceId: 2,
        serverName: 'Server 2',
        link: 'https://example.com/stream-2.m3u8',
        subtitle: '',
        type: 0,
        isFrame: false,
        quality: '720p',
        tracks: [],
      ),
      const PlaySource(
        sourceId: 3,
        serverName: 'Embedded source',
        link: 'https://example.com/embed-3',
        subtitle: '',
        type: 0,
        isFrame: true,
        quality: '480p',
        tracks: [],
      ),
    ];
  }

  @override
  Future<List<HomeSection>> loadHome() async => const [];

  @override
  Future<List<NavbarItem>> loadNavbar() async => const [];

  @override
  Future<PopupAdConfig?> loadPopupAd() async => null;
}

class _FakeApiClient extends MotchillApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

class _FakePlaybackController implements PlayerPlaybackController {
  _FakePlaybackController({
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) : _value = PlayerPlaybackValue(
         isInitialized: false,
         position: position,
         duration: duration,
         isPlaying: isPlaying,
         size: const Size(1280, 720),
       );

  final List<VoidCallback> _listeners = <VoidCallback>[];
  PlayerPlaybackValue _value;

  PlayTrack? audioTrack;
  PlayTrack? subtitleTrack;

  @override
  PlayerPlaybackValue get value => _value;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  Widget buildView() => const ColoredBox(color: Color(0xFF111111));

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {
    _setValue(_value.copyWith(isInitialized: true));
  }

  @override
  Future<void> pause() async {
    _setValue(_value.copyWith(isPlaying: false));
  }

  @override
  Future<void> play() async {
    _setValue(_value.copyWith(isPlaying: true));
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _setValue(_value.copyWith(position: position));
  }

  @override
  Future<void> setAudioTrack(PlayTrack? track) async {
    audioTrack = track;
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setSubtitleTrack(PlayTrack? track) async {
    subtitleTrack = track;
  }

  void _setValue(PlayerPlaybackValue next) {
    _value = next;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    debugBuildFramePlayerOverride = null;
    debugCreatePlaybackControllerOverride = null;
    Get.reset();
  });

  testWidgets('player shows inline source label and track buttons', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRepository();
    final fakeController = _FakePlaybackController(
      position: Duration.zero,
      duration: const Duration(minutes: 45),
      isPlaying: false,
    );

    Get.put<MotchillRepository>(repository);
    Get.lazyPut<PlayerController>(
      () => PlayerController(
        repository,
        movieId: 10,
        episodeId: 20,
        movieTitle: 'Oppenheimer',
        episodeLabel: 'Episode 1',
      ),
    );

    debugCreatePlaybackControllerOverride = (_) => fakeController;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/play/10/20',
        getPages: [
          GetPage(
            name: '/play/:movieId/:episodeId',
            page: () => const PlayerView(),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('player.surfaceTapTarget')), findsOneWidget);
    expect(find.byKey(const Key('player.sourceRailInline')), findsOneWidget);
    expect(find.text('Server 1'), findsWidgets);
    expect(find.text('1080p'), findsNothing);
    expect(find.byKey(const Key('player.sourceChip.2')), findsOneWidget);
    expect(find.text('Embedded source'), findsNothing);
    expect(find.byKey(const Key('player.audioTrackButton')), findsOneWidget);
    expect(find.byKey(const Key('player.subtitleTrackButton')), findsOneWidget);
    expect(find.byKey(const Key('player.progressRow')), findsOneWidget);
    expect(find.byKey(const Key('player.currentTime')), findsOneWidget);
    expect(find.byKey(const Key('player.totalTime')), findsOneWidget);
    expect(find.byKey(const Key('player.seekBack10')), findsOneWidget);
    expect(find.byKey(const Key('player.playPause')), findsOneWidget);
    expect(find.byKey(const Key('player.seekForward10')), findsOneWidget);

    await tester.tap(find.byKey(const Key('player.sourceChip.2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(Get.find<PlayerController>().selectedIndex.value, 1);
    expect(Get.find<PlayerController>().selectedSource?.sourceId, 2);
    expect(find.text('Server 2'), findsWidgets);
    expect(find.byKey(const Key('player.audioTrackButton')), findsNothing);
    expect(find.byKey(const Key('player.subtitleTrackButton')), findsNothing);
  });

  testWidgets('player remote focus navigates across control rows', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRepository();
    final fakeController = _FakePlaybackController(
      position: Duration.zero,
      duration: const Duration(minutes: 45),
      isPlaying: false,
    );

    Get.put<MotchillRepository>(repository);
    Get.lazyPut<PlayerController>(
      () => PlayerController(
        repository,
        movieId: 10,
        episodeId: 20,
        movieTitle: 'Oppenheimer',
        episodeLabel: 'Episode 1',
      ),
    );

    debugCreatePlaybackControllerOverride = (_) => fakeController;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/play/10/20',
        getPages: [
          GetPage(
            name: '/play/:movieId/:episodeId',
            page: () => const PlayerView(),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.source.0'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.progress'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.seekBack10'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.progress'));

    await tester.tapAt(const Offset(640, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byKey(const Key('player.progressRow')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('player.progressRow')), findsOneWidget);
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.playPause'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.seekForward10'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.playPause'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.progress'));
  });

  testWidgets('player remote up from source focuses back button', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRepository();
    final fakeController = _FakePlaybackController(
      position: Duration.zero,
      duration: const Duration(minutes: 45),
      isPlaying: false,
    );

    Get.put<MotchillRepository>(repository);
    Get.lazyPut<PlayerController>(
      () => PlayerController(
        repository,
        movieId: 10,
        episodeId: 20,
        movieTitle: 'Oppenheimer',
        episodeLabel: 'Episode 1',
      ),
    );

    debugCreatePlaybackControllerOverride = (_) => fakeController;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/play/10/20',
        getPages: [
          GetPage(
            name: '/play/:movieId/:episodeId',
            page: () => const PlayerView(),
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.source.0'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      contains('player.backButton'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, contains('player.source.0'));
  });

  test('player back key handler activates back and source focus', () {
    var backCount = 0;
    var focusCount = 0;

    expect(
      handlePlayerBackKey(
        LogicalKeyboardKey.enter,
        onBack: () => backCount += 1,
        onFocusSource0: () => focusCount += 1,
      ),
      KeyEventResult.handled,
    );
    expect(backCount, 1);
    expect(focusCount, 0);

    expect(
      handlePlayerBackKey(
        LogicalKeyboardKey.arrowDown,
        onBack: () => backCount += 1,
        onFocusSource0: () => focusCount += 1,
      ),
      KeyEventResult.handled,
    );
    expect(backCount, 1);
    expect(focusCount, 1);
  });
}
