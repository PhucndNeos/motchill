import assert from 'node:assert/strict';
import test from 'node:test';

import CryptoJS from 'crypto-js';

import { CONFIG } from '../src/config.js';
import { decryptWebSourcePayload, resolvePlaybackSource } from '../src/motchill.js';

function encryptWebSourcePayload(value) {
  const encrypted = CryptoJS.AES.encrypt(
    JSON.stringify(value),
    CryptoJS.enc.Utf8.parse(CONFIG.webSourceKey),
    {
      iv: CryptoJS.enc.Utf8.parse(CONFIG.webSourceIv),
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7,
    },
  );

  return encrypted.ciphertext.toString(CryptoJS.enc.Base64);
}

test('decryptWebSourcePayload decrypts the web embed payload shape', () => {
  const payload = {
    Link: 'https://cdn2.streambeta.cc/stream/play/example.m3u8',
    SubLink: '/movie/subtitles/example.vtt',
    Tracks: JSON.stringify([
      {
        kind: 'captions',
        file: 'https://cdn.example.com/subs/example.vtt',
        label: 'Tiếng Việt',
        default: true,
      },
    ]),
    IsIframe: true,
  };

  const ciphertext = encryptWebSourcePayload(payload);
  const decrypted = decryptWebSourcePayload(ciphertext);

  assert.equal(decrypted.Link, payload.Link);
  assert.equal(decrypted.SubLink, payload.SubLink);
  assert.equal(decrypted.IsIframe, true);
  assert.equal(Array.isArray(JSON.parse(decrypted.Tracks)), true);
});

test('resolvePlaybackSource turns a SourceId embed into a native-playable HLS URL', async () => {
  const sampleSource = {
    SourceId: 630207,
    ServerName: 'Vietsub 4K',
    Link: 'https://embed.vixos.store/embed/630207',
    Subtitle: 'https://cdn.motchilltv.me/movie/subtitles/example.vtt',
    Type: 1,
    IsFrame: true,
    Tracks: [],
  };

  const webPayload = {
    Link: 'https://cdn2.streambeta.cc/stream/play/71c4b4b8-da0c-44b3-a495-4f6ab01e3a16.m3u8',
    SubLink:
      '/movie/subtitles/20260303/6973c5a2-4b21-4a9b-96d4-7b8ed0ce93ad/82872a3e-b687-4642-b22a-4da8665b06c7.vtt',
    Tracks: JSON.stringify([
      {
        kind: 'captions',
        file: 'https://cdn.motchilltv.me/movie/subtitles/20260303/6973c5a2-4b21-4a9b-96d4-7b8ed0ce93ad/82872a3e-b687-4642-b22a-4da8665b06c7.vtt',
        label: 'Tiếng Việt',
        default: true,
      },
    ]),
    IsIframe: true,
  };

  const ciphertext = encryptWebSourcePayload(webPayload);
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/api/source/630207')) {
      return new Response(ciphertext, {
        status: 200,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    if (url === webPayload.Link) {
      return new Response(
        '#EXTM3U\n#EXTINF:10,\nhttps://cdn.example.com/seg1.ts\n#EXTINF:10,\nhttps://cdn.example.com/seg2.ts\n',
        {
          status: 200,
          headers: { 'content-type': 'application/vnd.apple.mpegurl; charset=utf-8' },
        },
      );
    }

    if (url === 'https://cdn.example.com/seg1.ts' || url === 'https://cdn.example.com/seg2.ts') {
      return new Response('', { status: 200 });
    }

    throw new Error(`Unexpected fetch: ${url}`);
  };

  try {
    const resolved = await resolvePlaybackSource(sampleSource, 0);

    assert.equal(resolved.available, true);
    assert.equal(resolved.playbackKind, 'hls');
    assert.equal(
      resolved.mediaUrl,
      'https://cdn2.streambeta.cc/stream/play/71c4b4b8-da0c-44b3-a495-4f6ab01e3a16.m3u8',
    );
    assert.equal(resolved.label, 'Vietsub 4K');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('resolvePlaybackSource rejects HLS sources whose first segments fail', async () => {
  const sampleSource = {
    SourceId: 630218,
    ServerName: 'Vietsub 1',
    Link: 'https://cdn.vixos.store/stream/play/d1ce483a-d482-42bb-8e82-ceb7819d7361.m3u8',
    Type: 1,
    IsFrame: false,
  };

  const webPayload = {
    Link: 'https://cdn.vixos.store/stream/play/d1ce483a-d482-42bb-8e82-ceb7819d7361.m3u8',
    Tracks: '[]',
    IsIframe: false,
  };

  const ciphertext = encryptWebSourcePayload(webPayload);
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/api/source/630218')) {
      return new Response(ciphertext, {
        status: 200,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    if (url === webPayload.Link) {
      return new Response(
        '#EXTM3U\n#EXTINF:10,\nhttps://bad.example/seg1.ts\n#EXTINF:10,\nhttps://bad.example/seg2.ts\n',
        {
          status: 200,
          headers: { 'content-type': 'application/vnd.apple.mpegurl; charset=utf-8' },
        },
      );
    }

    if (url.startsWith('https://bad.example/seg')) {
      return new Response('', { status: 500 });
    }

    throw new Error(`Unexpected fetch: ${url}`);
  };

  try {
    const resolved = await resolvePlaybackSource(sampleSource, 0);

    assert.equal(resolved.available, false);
    assert.equal(resolved.playbackKind, 'unsupported');
    assert.equal(resolved.error, 'HLS segments returned an error');
  } finally {
    globalThis.fetch = originalFetch;
  }
});
