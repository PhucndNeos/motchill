# Player Position Resume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the player timeline stable when switching between collapsed and expanded layouts, and resume the same episode near the last watched position when the user returns later.

**Architecture:** Add a tiny local persistence layer for playback position keyed by `movieId + episodeId`, then wire the player frame to keep a live in-memory snapshot of position/duration while the screen is open. Expand/collapse should reuse the same playback session, while the cache only kicks in on reopen, pause, and periodic sync.

**Tech Stack:** Flutter, GetX, `video_player`, `shared_preferences`, `flutter_test`

---

### Task 1: Add the local playback position store

**Files:**
- Modify: `mobile-api-base/pubspec.yaml`
- Modify: `mobile-api-base/pubspec.lock`
- Create: `mobile-api-base/lib/features/player/playback_position_store.dart`
- Create: `mobile-api-base/test/features/player/playback_position_store_test.dart`

- [ ] **Step 1: Write the failing store test**

Create a test that saves and loads a resume position for a specific episode key.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_api_base/features/player/playback_position_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores and restores episode position', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlaybackPositionStore();

    await store.save(
      movieId: 10,
      episodeId: 20,
      position: const Duration(minutes: 20, seconds: 15),
    );

    final loaded = await store.load(movieId: 10, episodeId: 20);

    expect(loaded, const Duration(minutes: 20, seconds: 15));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd mobile-api-base && flutter test test/features/player/playback_position_store_test.dart
```

Expected: fail because `shared_preferences` is not yet added and the store file does not exist.

- [ ] **Step 3: Add the dependency and minimal store**

Add `shared_preferences` to `pubspec.yaml`, then implement a small store with episode-scoped keys.

```dart
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPositionStore {
  static String _key({required int movieId, required int episodeId}) =>
      'player_position:$movieId:$episodeId';

  Future<void> save({
    required int movieId,
    required int episodeId,
    required Duration position,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(movieId: movieId, episodeId: episodeId), position.inMilliseconds);
  }

  Future<Duration?> load({
    required int movieId,
    required int episodeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key(movieId: movieId, episodeId: episodeId));
    if (value == null || value < 0) return null;
    return Duration(milliseconds: value);
  }
}
```

- [ ] **Step 4: Run the store test until it passes**

Run:

```bash
cd mobile-api-base && flutter test test/features/player/playback_position_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the store work**

```bash
git add mobile-api-base/pubspec.yaml \
  mobile-api-base/pubspec.lock \
  mobile-api-base/lib/features/player/playback_position_store.dart \
  mobile-api-base/test/features/player/playback_position_store_test.dart
git commit -m "feat: add playback position store"
```

### Task 2: Wire player session sync and restore

**Files:**
- Modify: `mobile-api-base/lib/features/player/player_binding.dart`
- Modify: `mobile-api-base/lib/features/player/player_view.dart`
- Modify: `mobile-api-base/lib/features/player/frame_player_stub.dart`
- Modify: `mobile-api-base/lib/app/bindings/initial_binding.dart`
- Create: `mobile-api-base/test/player_position_resume_test.dart`

- [ ] **Step 1: Write the failing resume test**

Create a widget test that injects a fake position store with a saved `20:00` resume point, pumps the player, and verifies that the visible time stays on `20:00` when the chrome layout switches between collapsed and expanded.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mobile_api_base/features/player/player_view.dart';
import 'package:mobile_api_base/features/player/playback_position_store.dart';

class _FakePositionStore extends PlaybackPositionStore {
  Duration? savedPosition;

  _FakePositionStore(this.savedPosition);

  @override
  Future<void> save({
    required int movieId,
    required int episodeId,
    required Duration position,
  }) async {
    savedPosition = position;
  }

  @override
  Future<Duration?> load({
    required int movieId,
    required int episodeId,
  }) async {
    return savedPosition;
  }
}

testWidgets('player keeps live position across expand and collapse', (
  WidgetTester tester,
) async {
  final store = _FakePositionStore(const Duration(minutes: 20));
  Get.put<PlaybackPositionStore>(store);

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

  await tester.pumpAndSettle();
  expect(find.text('20:00'), findsWidgets);

  await tester.tap(find.byKey(const Key('player.expandToggle')));
  await tester.pumpAndSettle();
  expect(find.text('20:00'), findsWidgets);

  await tester.tap(find.byKey(const Key('player.collapseToggle')));
  await tester.pumpAndSettle();
  expect(find.text('20:00'), findsWidgets);
});
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run:

```bash
cd mobile-api-base && flutter test test/player_position_resume_test.dart
```

Expected: fail because the player does not yet restore/sync the cached position on toggle.

- [ ] **Step 3: Add the live session sync**

Update `PlayerFrame` so it keeps a live `Duration position` snapshot in memory and writes the current position to the store when:

```dart
Future<void> _syncSnapshot() async {
  final controller = _streamController;
  if (controller == null || !controller.value.isInitialized) return;

  final value = controller.value;
  _position = value.position;
  _duration = value.duration;
  _isPlaying = value.isPlaying;
}

Future<void> _persistPosition() async {
  await _positionStore.save(
    movieId: widget.movieId,
    episodeId: widget.episodeId,
    position: _position,
  );
}
```

Make expand/collapse call the same `_syncSnapshot()` path before repainting the chrome so the visible progress row stays aligned with the current playback time. Keep the player surface keyed as `player.surface` so the subtree does not lose its timeline state when only the chrome changes.

- [ ] **Step 4: Restore the cached position on init**

When the stream controller initializes, load the cached position for the current episode and seek to it before normal playback continues.

```dart
final savedPosition = await _positionStore.load(
  movieId: movieId,
  episodeId: episodeId,
);
if (savedPosition != null && savedPosition > Duration.zero) {
  await controller.seekTo(savedPosition);
}
```

Add the store to `InitialBinding` so the player can find it through GetX, and pass the episode identifiers through `PlayerBinding` so the frame can load and save against `movieId + episodeId`.

- [ ] **Step 5: Persist on pause, back, and timer**

Save the current position:

```dart
// every 5 seconds while the stream is playing
// when the user pauses playback
// when the player screen disposes
```

Also update the expand/collapse toggle path so it snapshots the latest position immediately before switching layout state.

- [ ] **Step 6: Run the widget test until it passes**

Run:

```bash
cd mobile-api-base && flutter test test/player_position_resume_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run the full suite**

Run:

```bash
cd mobile-api-base && flutter test
```

Expected: PASS.

- [ ] **Step 8: Commit the player sync work**

```bash
git add mobile-api-base/lib/features/player/player_controller.dart \
  mobile-api-base/lib/features/player/player_binding.dart \
  mobile-api-base/lib/features/player/player_view.dart \
  mobile-api-base/lib/features/player/frame_player_stub.dart \
  mobile-api-base/lib/app/bindings/initial_binding.dart \
  mobile-api-base/test/player_position_resume_test.dart
git commit -m "feat: preserve player position across layouts"
```

### Task 3: Verify resume behavior and tidy docs

**Files:**
- Modify: `docs/superpowers/specs/2026-04-08-player-position-resume-design.md` only if the implementation reveals an unavoidable behavior change
- Modify: `mobile-api-base/README.md` only if the app run instructions need a note about resume behavior

- [ ] **Step 1: Validate the resume rules against the spec**

Check that:

```text
expand/collapse never resets the visible timeline
reopening the same episode resumes from the cached position
invalid or missing cache entries fall back to 0:00
```

- [ ] **Step 2: Update docs only if needed**

If the implementation changes any concrete behavior from the spec, update the spec doc and keep the wording aligned with the actual code path.

- [ ] **Step 3: Final commit if docs changed**

```bash
git add docs/superpowers/specs/2026-04-08-player-position-resume-design.md mobile-api-base/README.md
git commit -m "docs: align player resume docs"
```
