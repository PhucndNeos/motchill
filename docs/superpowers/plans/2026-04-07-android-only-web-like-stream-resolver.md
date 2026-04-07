# Android-Only Web-Like Stream Resolver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Archive note:** This is a historical plan from before the repo was consolidated into `mobile-api-base` and before the current player architecture changed. Keep it for context only; the paths and backend assumptions below are not the current codebase state.

**Goal:** Resolve playback the same way the web embed does, then expose only native-playable URLs to Flutter so Android and iOS can use `video_player` without WebView fallback.

**Architecture:** The backend will fetch `/api/source/:id`, decrypt the payload with the same AES-CBC parameters the web uses, and normalize `Link`, `SubLink`, and track metadata into a stable playback response. Flutter will request playback from the backend, show only sources that the backend can resolve, and fail dead sources fast with a toast instead of switching into a broken state.

**Tech Stack:** Node.js, Fastify, CryptoJS, Cheerio, Flutter, `video_player`, `http`

---

### Task 1: Add web-like source decryption in the backend

**Files:**
- Modify: `/Users/phucnd/Documents/motchill/backend/src/motchill.js`
- Test: `/Users/phucnd/Documents/motchill/backend/test/playback-resolver.test.mjs`

- [ ] **Step 1: Write the failing test**

```js
import assert from 'node:assert/strict';
import test from 'node:test';
import { decryptWebSourcePayload } from '../src/motchill.js';

test('decrypts embed source payload into a playback object', () => {
  const payload = 'replace-with-captured-base64-ciphertext';
  const result = decryptWebSourcePayload(payload);

  assert.equal(result.Link, 'https://cdn2.streambeta.cc/stream/play/71c4b4b8-da0c-44b3-a495-4f6ab01e3a16.m3u8');
  assert.equal(result.SubLink, '/movie/subtitles/20260303/6973c5a2-4b21-4a9b-96d4-7b8ed0ce93ad/82872a3e-b687-4642-b22a-4da8665b06c7.vtt');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/phucnd/Documents/motchill/backend && node --test test/playback-resolver.test.mjs`
Expected: FAIL because `decryptWebSourcePayload` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```js
const WEB_SOURCE_KEY = '13354665901265567120123456777992';
const WEB_SOURCE_IV = '1254566897125456';

export function decryptWebSourcePayload(ciphertext) {
  const bytes = CryptoJS.AES.decrypt(
    {
      ciphertext: CryptoJS.enc.Base64.parse(ciphertext),
    },
    CryptoJS.enc.Utf8.parse(WEB_SOURCE_KEY),
    {
      iv: CryptoJS.enc.Utf8.parse(WEB_SOURCE_IV),
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7,
    },
  );

  const plainText = bytes.toString(CryptoJS.enc.Utf8);
  if (!plainText) throw new Error('Failed to decrypt web source payload');
  return JSON.parse(plainText);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/phucnd/Documents/motchill/backend && node --test test/playback-resolver.test.mjs`
Expected: PASS and the decrypted object contains `Link`, `SubLink`, and `Tracks`.

- [ ] **Step 5: Commit**

```bash
git add /Users/phucnd/Documents/motchill/backend/src/motchill.js /Users/phucnd/Documents/motchill/backend/test/playback-resolver.test.mjs
git commit -m "feat: decrypt web source payload"
```

### Task 2: Resolve playback through web source objects and HLS relay

**Files:**
- Modify: `/Users/phucnd/Documents/motchill/backend/src/motchill.js`
- Modify: `/Users/phucnd/Documents/motchill/backend/src/server.js`
- Test: `/Users/phucnd/Documents/motchill/backend/test/playback-api.test.mjs`

- [ ] **Step 1: Write the failing test**

```js
import assert from 'node:assert/strict';
import test from 'node:test';
import { buildPlaybackFromWebSource } from '../src/motchill.js';

test('builds a playable HLS response from a decrypted source object', () => {
  const playback = buildPlaybackFromWebSource({
    Link: 'https://cdn2.streambeta.cc/stream/play/example.m3u8',
    SubLink: '/movie/subtitles/example.vtt',
    Tracks: '[]',
    IsIframe: false,
  });

  assert.equal(playback.playbackKind, 'hls');
  assert.equal(playback.mediaUrl, 'https://cdn2.streambeta.cc/stream/play/example.m3u8');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/phucnd/Documents/motchill/backend && node --test test/playback-api.test.mjs`
Expected: FAIL because `buildPlaybackFromWebSource` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```js
function buildPlaybackFromWebSource(source, { referer } = {}) {
  const mediaUrl = normalizePlayableCandidate(source.Link || source.link || '', referer || CONFIG.baseUrl);
  const playbackKind = mediaUrl?.toLowerCase().includes('.m3u8') ? 'hls' : 'file';
  return {
    playbackKind,
    mediaUrl,
    mediaReferer: referer || CONFIG.baseUrl,
    subtitlesUrl: normalizePlayableCandidate(source.SubLink || source.subLink || '', referer || CONFIG.baseUrl),
    tracks: parseTracks(source.Tracks || source.tracks),
    raw: source,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/phucnd/Documents/motchill/backend && node --test test/playback-api.test.mjs`
Expected: PASS and `/api/playback/:slug` returns the normalized playable URL for the Android/iOS player.

- [ ] **Step 5: Commit**

```bash
git add /Users/phucnd/Documents/motchill/backend/src/motchill.js /Users/phucnd/Documents/motchill/backend/src/server.js /Users/phucnd/Documents/motchill/backend/test/playback-api.test.mjs
git commit -m "feat: resolve playback from web source"
```

### Task 3: Make Flutter playback source-aware and dead-source safe

**Files:**
- Modify: `/Users/phucnd/Documents/motchill/mobile/lib/src/models.dart`
- Modify: `/Users/phucnd/Documents/motchill/mobile/lib/src/api.dart`
- Modify: `/Users/phucnd/Documents/motchill/mobile/lib/src/data/motchill_repository.dart`
- Modify: `/Users/phucnd/Documents/motchill/mobile/lib/src/features/player/player_controller.dart`
- Modify: `/Users/phucnd/Documents/motchill/mobile/lib/src/screens/player_screen.dart`
- Test: `/Users/phucnd/Documents/motchill/mobile/test/models_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/models.dart';

void main() {
  test('PlaybackInfo exposes only backend-resolved source choices', () {
    final info = PlaybackInfo.fromJson({
      'movieId': 1,
      'episodeId': 2,
      'server': 0,
      'playbackKind': 'hls',
      'streamUrl': 'https://example.com/master.m3u8',
      'mediaUrl': 'https://example.com/master.m3u8',
      'mediaReferer': 'https://example.com',
      'sources': [
        {'serverName': 'Source A', 'resolved': true},
        {'serverName': 'Source B', 'resolved': false},
      ],
      'raw': [],
    });

    expect(info.sourceChoices.length, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/phucnd/Documents/motchill/mobile && flutter test test/models_test.dart -r expanded`
Expected: FAIL because the model/controller still assumes old source handling.

- [ ] **Step 3: Write minimal implementation**

```dart
Future<bool> selectSource(int index) async {
  final prepared = await _preparePlayback(
    episodeIndex: _selectedIndex,
    sourceIndex: index,
    allowSourceFallback: false,
  );
  if (prepared == null) {
    _error = 'Source unavailable, please choose another one.';
    notifyListeners();
    return false;
  }
  // commit source only after initialize succeeds
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/phucnd/Documents/motchill/mobile && flutter test test/models_test.dart -r expanded`
Expected: PASS and the UI shows a toast when a source cannot initialize.

- [ ] **Step 5: Commit**

```bash
git add /Users/phucnd/Documents/motchill/mobile/lib/src/models.dart /Users/phucnd/Documents/motchill/mobile/lib/src/api.dart /Users/phucnd/Documents/motchill/mobile/lib/src/data/motchill_repository.dart /Users/phucnd/Documents/motchill/mobile/lib/src/features/player/player_controller.dart /Users/phucnd/Documents/motchill/mobile/lib/src/screens/player_screen.dart /Users/phucnd/Documents/motchill/mobile/test/models_test.dart
git commit -m "feat: make player source-aware"
```

### Task 4: Verify Android/iOS playback and dead-source handling end to end

**Files:**
- Test only: backend and Flutter simulator/device runtime

- [ ] **Step 1: Run backend tests**

Run: `cd /Users/phucnd/Documents/motchill/backend && npm test`
Expected: PASS.

- [ ] **Step 2: Run Flutter analysis and tests**

Run: `cd /Users/phucnd/Documents/motchill/mobile && flutter analyze && flutter test`
Expected: PASS.

- [ ] **Step 3: Launch the app on simulator and verify playback**

Run: `cd /Users/phucnd/Documents/motchill/mobile && flutter run -d ios`
Expected: detail opens, Play starts playback, source picker shows only resolvable sources, and dead sources toast instead of switching.

- [ ] **Step 4: Commit any verification-only changes**

```bash
git add -A
git commit -m "chore: verify web-like playback resolver"
```
