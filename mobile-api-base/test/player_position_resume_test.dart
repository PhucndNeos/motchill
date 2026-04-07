import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mobile_api_base/core/network/motchill_api_client.dart';
import 'package:mobile_api_base/data/models/motchill_models.dart';
import 'package:mobile_api_base/data/models/motchill_play_models.dart';
import 'package:mobile_api_base/data/repositories/motchill_repository.dart';
import 'package:mobile_api_base/features/player/playback_position_store.dart';
import 'package:mobile_api_base/features/player/player_controller.dart';
import 'package:mobile_api_base/features/player/player_view.dart';

class _FakeRepository extends MotchillRepository {
  _FakeRepository({required this.sources}) : super(apiClient: _FakeApiClient());

  final List<PlaySource> sources;

  @override
  Future<List<PlaySource>> loadEpisodeSources({
    required int movieId,
    required int episodeId,
    int server = 0,
  }) async => sources;

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

class _FakePlaybackPositionStore extends PlaybackPositionStore {
  _FakePlaybackPositionStore(this.savedPosition);

  Duration? savedPosition;
  final List<Duration> saves = <Duration>[];

  @override
  Future<void> save(int movieId, int episodeId, Duration position) async {
    savedPosition = position;
    saves.add(position);
  }

  @override
  Future<Duration?> load(int movieId, int episodeId) async => savedPosition;
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

  int initializeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
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
    initializeCalls += 1;
    _setValue(_value.copyWith(isInitialized: true));
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _setValue(_value.copyWith(isPlaying: false));
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    _setValue(_value.copyWith(isPlaying: true));
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  Future<void> seekTo(Duration position) async {
    seekCalls += 1;
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

  void tick(Duration position) {
    _setValue(_value.copyWith(position: position));
  }

  void _setValue(PlayerPlaybackValue next) {
    _value = next;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

class _FakeEmbeddedSurface extends StatefulWidget {
  const _FakeEmbeddedSurface();

  static int initCount = 0;

  @override
  State<_FakeEmbeddedSurface> createState() => _FakeEmbeddedSurfaceState();
}

class _FakeEmbeddedSurfaceState extends State<_FakeEmbeddedSurface> {
  @override
  void initState() {
    super.initState();
    _FakeEmbeddedSurface.initCount += 1;
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF222222),
      child: SizedBox.expand(key: Key('fake.embedded.surface')),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    debugCreatePlaybackControllerOverride = null;
    debugBuildFramePlayerOverride = null;
    Get.reset();
  });

  testWidgets(
    'player restores saved position and keeps visible time in landscape mode',
    (tester) async {
      final repository = _FakeRepository(
        sources: const [
          PlaySource(
            sourceId: 1,
            serverName: 'Direct Stream',
            link: 'https://example.com/stream.m3u8',
            subtitle: '',
            type: 0,
            isFrame: false,
            quality: '1080p',
            tracks: [],
          ),
        ],
      );
      final store = _FakePlaybackPositionStore(const Duration(minutes: 20));
      final fakeController = _FakePlaybackController(
        position: Duration.zero,
        duration: const Duration(minutes: 45),
        isPlaying: false,
      );

      Get.put<MotchillRepository>(repository);
      Get.put<PlaybackPositionStore>(store);
      Get.lazyPut<PlayerController>(
        () => PlayerController(
          repository,
          movieId: 10,
          episodeId: 20,
          movieTitle: 'Movie',
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
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('player.sourceRailInline')), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(fakeController.initializeCalls, 1);
      expect(fakeController.seekCalls, 1);

      expect(fakeController.initializeCalls, 1);
      expect(store.savedPosition, const Duration(minutes: 20));
    },
  );

  testWidgets(
    'player shows error when only embed sources are available',
    (tester) async {
      final repository = _FakeRepository(
        sources: const [
          PlaySource(
            sourceId: 2,
            serverName: 'Embedded Frame',
            link: 'https://example.com/embed-1',
            subtitle: '',
            type: 0,
            isFrame: true,
            quality: '720p',
            tracks: [],
          ),
        ],
      );

      Get.put<MotchillRepository>(repository);
      Get.lazyPut<PlayerController>(
        () => PlayerController(
          repository,
          movieId: 10,
          episodeId: 20,
          movieTitle: 'Movie',
          episodeLabel: 'Episode 1',
        ),
      );

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
      await tester.pump(const Duration(milliseconds: 200));

      expect(Get.find<PlayerController>().sources, isEmpty);
      expect(
        find.text('No source available, try again later'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('player.sourceRailInline')), findsNothing);
    },
  );

  testWidgets(
    'player preserves position when switching sources',
    (tester) async {
      final repository = _FakeRepository(
        sources: const [
          PlaySource(
            sourceId: 1,
            serverName: 'Server 1',
            link: 'https://example.com/stream-1.m3u8',
            subtitle: '',
            type: 0,
            isFrame: false,
            quality: '1080p',
            tracks: [],
          ),
          PlaySource(
            sourceId: 2,
            serverName: 'Server 2',
            link: 'https://example.com/stream-2.m3u8',
            subtitle: '',
            type: 0,
            isFrame: false,
            quality: '720p',
            tracks: [],
          ),
        ],
      );
      final store = _FakePlaybackPositionStore(const Duration(minutes: 20));
      final controllers = <String, _FakePlaybackController>{};

      Get.put<MotchillRepository>(repository);
      Get.put<PlaybackPositionStore>(store);
      Get.lazyPut<PlayerController>(
        () => PlayerController(
          repository,
          movieId: 10,
          episodeId: 20,
          movieTitle: 'Movie',
          episodeLabel: 'Episode 1',
        ),
      );

      debugCreatePlaybackControllerOverride = (source) {
        return controllers.putIfAbsent(
          source.link,
          () => _FakePlaybackController(
            position: Duration.zero,
            duration: const Duration(minutes: 45),
            isPlaying: false,
          ),
        );
      };

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
      await tester.pump(const Duration(milliseconds: 200));

      final firstController = controllers['https://example.com/stream-1.m3u8'];
      expect(firstController, isNotNull);
      expect(firstController!.initializeCalls, 1);
      expect(firstController.seekCalls, 1);

      firstController.tick(const Duration(minutes: 20, seconds: 7));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(const Key('player.sourceChip.2')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final secondController = controllers['https://example.com/stream-2.m3u8'];
      expect(secondController, isNotNull);
      expect(store.savedPosition, const Duration(minutes: 20, seconds: 7));
      expect(secondController!.initializeCalls, 1);
      expect(secondController.seekCalls, 1);
    },
  );
}
