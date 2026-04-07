import test from 'node:test';
import assert from 'node:assert/strict';

import {
  extractFallbackUrl,
  rewritePlaylist,
  selectPlayableStreamUrl,
  selectPlaybackSource,
} from '../src/motchill.js';

test('rewritePlaylist proxies segment urls through backend fetch route', () => {
  const playlist = [
    '#EXTM3U',
    '#EXT-X-VERSION:3',
    '#EXTINF:10.0,',
    'https://cdn.example.com/video/seg-1.ts',
    '#EXTINF:10.0,',
    'seg-2.ts',
    '',
  ].join('\n');

  const out = rewritePlaylist(playlist, {
    playlistUrl: 'https://origin.example.com/path/master.m3u8',
    proxyBaseUrl: 'http://127.0.0.1:3000',
  });

  assert.match(out, /#EXTM3U/);
  assert.match(out, /#EXT-X-VERSION:3/);
  assert.match(out, /http:\/\/127\.0\.0\.1:3000\/api\/hls\/fetch\?url=/);
  assert.match(out, /url=https%3A%2F%2Fcdn\.example\.com%2Fvideo%2Fseg-1\.ts/);
  assert.match(out, /url=https%3A%2F%2Forigin\.example\.com%2Fpath%2Fseg-2\.ts/);
  assert.match(out, /referer=https%3A%2F%2Forigin\.example\.com%2Fpath%2Fmaster\.m3u8/);
});

test('extractFallbackUrl finds embedded player pages', () => {
  const payload = [
    { ServerName: 'Vietsub 1', Link: 'https://cdn.vixos.store/stream/play/example.m3u8' },
    { ServerName: 'Vietsub 4K', Link: 'https://embed.vixos.store/embed/630207' },
    { ServerName: 'Vietsub 3', Link: 'https://embed13.streamc.xyz/embed.php?hash=abc' },
  ];

  assert.equal(extractFallbackUrl(payload), 'https://embed.vixos.store/embed/630207');
});

test('selectPlayableStreamUrl prefers a direct non-tiktok HLS stream', () => {
  const payload = [
    { ServerName: 'Vietsub 1', Link: 'https://p16-sg.tiktokcdn.com/obj/tos-alisg-avt-0068/cc713c83586ce6b54afded17fce28ec2' },
    { ServerName: 'Vietsub 2', Link: 'https://vip.opstream10.com/20260303/32902_1532b681/index.m3u8' },
    { ServerName: 'Vietsub 3', Link: 'https://embed13.streamc.xyz/embed.php?hash=abc' },
  ];

  assert.equal(
    selectPlayableStreamUrl(payload),
    'https://vip.opstream10.com/20260303/32902_1532b681/index.m3u8',
  );
});

test('selectPlaybackSource returns the requested source entry', () => {
  const payload = [
    { ServerName: 'Vietsub 1', Link: 'https://cdn.vixos.store/stream/play/example-1.m3u8' },
    { ServerName: 'Vietsub 2', Link: 'https://vip.opstream10.com/example-2.m3u8' },
    { ServerName: 'Vietsub 3', Link: 'https://embed13.streamc.xyz/embed.php?hash=abc' },
  ];

  assert.equal(selectPlaybackSource(payload, 1).ServerName, 'Vietsub 2');
  assert.equal(selectPlaybackSource(payload, 99).ServerName, 'Vietsub 3');
  assert.equal(selectPlaybackSource(payload, -10).ServerName, 'Vietsub 1');
});
