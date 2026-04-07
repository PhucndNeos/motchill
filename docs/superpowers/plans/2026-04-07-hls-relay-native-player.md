# HLS Relay + Native Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Archive note:** This is a historical plan from when the project still assumed a backend HLS relay and a separate `mobile/` app. The current repository state no longer matches those paths or assumptions.

**Goal:** Make the app play video through `video_player` only, using a backend HLS relay/proxy that rewrites playlists and proxies segments so iOS/Android native players can open the stream directly.

**Architecture:** The backend remains the only place that talks to the upstream streaming hosts. It resolves playback metadata, rewrites playlists so every segment URI points back to the backend, and proxies segment bytes with the upstream headers needed to avoid TLS and hotlink issues. The Flutter app consumes only the backend relay URL and uses `video_player` as the sole playback mechanism; no WebView fallback remains in the product path.

**Tech Stack:** Node.js + Fastify backend, Flutter mobile app, `video_player`, HLS playlist rewriting, backend proxy tests, iOS Simulator verification.

---

### Task 1: Lock the backend into a native-playable HLS relay

**Files:**
- Modify: `backend/src/motchill.js`
- Modify: `backend/src/server.js`
- Modify: `backend/test/proxy.test.js`

- [ ] **Step 1: Write the failing test**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { extractFallbackUrl, rewritePlaylist } from '../src/motchill.js';

test('extractFallbackUrl prefers embed pages when present', () => {
  const payload = [
    { ServerName: 'Vietsub 1', Link: 'https://cdn.vixos.store/stream/play/example.m3u8' },
    { ServerName: 'Vietsub 4K', Link: 'https://embed.vixos.store/embed/630207' },
  ];

  assert.equal(extractFallbackUrl(payload), 'https://embed.vixos.store/embed/630207');
});

test('rewritePlaylist proxies every segment back through backend fetch route', () => {
  const playlist = [
    '#EXTM3U',
    '#EXTINF:10.0,',
    'seg-1.ts',
    '#EXTINF:10.0,',
    'https://cdn.example.com/video/seg-2.ts',
    '',
  ].join('\n');

  const out = rewritePlaylist(playlist, {
    playlistUrl: 'https://origin.example.com/path/master.m3u8',
    proxyBaseUrl: 'http://127.0.0.1:3000',
  });

  assert.match(out, /http:\/\/127\.0\.0\.1:3000\/api\/hls\/fetch\?url=/);
  assert.match(out, /url=https%3A%2F%2Forigin\.example\.com%2Fpath%2Fseg-1\.ts/);
  assert.match(out, /url=https%3A%2F%2Fcdn\.example\.com%2Fvideo%2Fseg-2\.ts/);
});
```

- [ ] **Step 2: Run the backend test to verify the current behavior**

Run: `cd backend && npm test`

Expected: the new assertions fail if fallback selection or playlist rewriting is incomplete.

- [ ] **Step 3: Implement the backend relay behavior**

```js
// In backend/src/motchill.js:
// - keep the decrypted raw source list
// - extract a playable HLS/MP4 URL for native playback
// - extract a browser embed URL only as metadata, not as the app playback path
// - return both from getPlayback() so the route can expose relay metadata

// In backend/src/server.js:
// - /api/playback/:slug returns streamUrl pointing at /api/hls/:movieId/:episodeId
// - /api/hls/:movieId/:episodeId fetches the upstream playlist and rewrites all media URIs to /api/hls/fetch?url=...
// - /api/hls/fetch proxies segment bytes using the upstream TLS workaround and browser-like headers
```

- [ ] **Step 4: Run the backend test to verify it passes**

Run: `cd backend && npm test`

Expected: all backend tests pass and `/api/playback/:slug` still returns a local HLS URL.

- [ ] **Step 5: Commit the backend relay work**

```bash
git add backend/src/motchill.js backend/src/server.js backend/test/proxy.test.js
git commit -m "feat: relay hls through backend proxy"
```

### Task 2: Remove WebView fallback and keep Flutter on native `video_player`

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/lib/src/models.dart`
- Modify: `mobile/lib/src/screens/detail_screen.dart`
- Modify: `mobile/lib/src/screens/player_screen.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/models.dart';

void main() {
  test('PlaybackInfo parses native stream fields', () {
    final info = PlaybackInfo.fromJson({
      'movieId': 1,
      'episodeId': 2,
      'server': 0,
      'streamUrl': 'http://127.0.0.1:3000/api/hls/1/2?server=0',
      'raw': [],
    });

    expect(info.streamUrl, contains('/api/hls/1/2'));
    expect(info.fallbackUrl, isNull);
    expect(info.sources, isEmpty);
  });
}
```

- [ ] **Step 2: Run Flutter tests to confirm current coverage**

Run: `cd mobile && flutter test`

Expected: this test fails until `PlaybackInfo` and player screen are cleaned up for native-only playback.

- [ ] **Step 3: Remove the WebView branch and wire `video_player` to the backend relay**

```dart
// In mobile/lib/src/screens/player_screen.dart:
// - remove webview_flutter imports and code
// - keep a single VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl))
// - keep the retry button for native HLS init failures
// - preserve the overflow fix in the error widget so long error messages scroll

// In mobile/lib/src/screens/detail_screen.dart:
// - pass only playback.streamUrl into PlayerScreen
// - do not pass or display any browser fallback URL
```

- [ ] **Step 4: Run Flutter analyze and tests**

Run:
`cd mobile && flutter analyze`
`cd mobile && flutter test`

Expected: analyze is clean and tests pass with the native-only player path.

- [ ] **Step 5: Commit the Flutter cleanup**

```bash
git add mobile/pubspec.yaml mobile/lib/src/models.dart mobile/lib/src/screens/detail_screen.dart mobile/lib/src/screens/player_screen.dart
git commit -m "feat: keep playback native with hls relay"
```

### Task 3: Rebuild the iOS simulator and verify native playback

**Files:**
- No code changes expected unless simulator verification exposes a real playback defect.

- [ ] **Step 1: Reinstall iOS pods after dependency changes**

Run: `cd mobile/ios && pod install`

Expected: CocoaPods reports the Runner target is integrated cleanly.

- [ ] **Step 2: Build and run the app on the booted simulator**

Run: `XcodeBuildMCP build_run_sim`

Expected: the app launches on the existing booted iPhone simulator without WebView dependencies.

- [ ] **Step 3: Reproduce the playback path on a real episode**

Use the simulator UI to open `Nụ Hôn Siren`, press `Play Tập 1`, and confirm one of two outcomes:

```text
PASS: video_player starts playback directly through the backend relay URL.
FAIL: the player still errors, which means the backend relay is not serving a native-playable stream yet.
```

- [ ] **Step 4: Capture logs if playback still fails**

Run:
`XcodeBuildMCP start_sim_log_cap`
`XcodeBuildMCP stop_sim_log_cap`

Expected: the logs show whether the failure is HTTP, playlist rewrite, segment proxy, or AVPlayer/ExoPlayer format support.

- [ ] **Step 5: Commit the verification results if no further code changes are needed**

```bash
git add -A
git commit -m "test: verify native hls playback on simulator"
```
