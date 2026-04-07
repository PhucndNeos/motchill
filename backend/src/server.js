import fastify from 'fastify';
import cors from '@fastify/cors';
import { Readable } from 'node:stream';
import {
  getEpisodeDetail,
  getHome,
  getPlayback,
  getPlaybackManifest,
  getMovieDetail,
  decryptWebSourcePayload,
  fetchText,
  refreshCatalogSnapshot,
  rewritePlaylist,
  searchMovies,
} from './motchill.js';
import { CONFIG } from './config.js';

const app = fastify({
  logger: true,
});

function getProxyBaseUrl(request) {
  const host = request.headers.host || `127.0.0.1:${CONFIG.port}`;
  return `${request.protocol}://${host}`;
}

async function proxyBinaryUrl(targetUrl, referer) {
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Codex Motchill Backend)',
    Accept: '*/*',
  };

  if (referer) {
    headers.Referer = referer;
    headers.Origin = new URL(referer).origin;
  }

  const response = await fetch(targetUrl, { headers, redirect: 'follow' });
  const body = response.body ? Readable.fromWeb(response.body) : null;
  return {
    statusCode: response.status,
    headers: Object.fromEntries(response.headers.entries()),
    body,
  };
}

await app.register(cors, {
  origin: true,
  methods: ['GET', 'POST', 'OPTIONS'],
});

let refreshInFlight = null;

async function refreshCatalogSafely() {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = refreshCatalogSnapshot({ limit: 24 })
    .then((result) => {
      app.log.info({ result }, 'catalog snapshot refreshed');
      return result;
    })
    .catch((error) => {
      app.log.error(error, 'catalog snapshot refresh failed');
      throw error;
    })
    .finally(() => {
      refreshInFlight = null;
    });
  return refreshInFlight;
}

app.get('/health', async () => ({ ok: true }));

app.get('/api/home', async () => getHome());

app.get('/api/search', async (request) => {
  const query = String(request.query.q || request.query.searchtext || '').trim();
  if (!query) {
    return { query, cards: [] };
  }
  return searchMovies(query);
});

app.get('/api/episode/:slug', async (request) => {
  const { slug } = request.params;
  try {
    return getEpisodeDetail(slug);
  } catch {
    return getMovieDetail(slug);
  }
});

app.get('/api/movie/:slug', async (request) => {
  const { slug } = request.params;
  return getMovieDetail(slug);
});

app.get('/api/source/:id', async (request) => {
  const { id } = request.params;
  const payload = await fetchText(`/api/source/${encodeURIComponent(id)}`, {
    referer: `${CONFIG.baseUrl}/`,
  });
  return {
    sourceId: Number.parseInt(String(id), 10) || 0,
    payload: decryptWebSourcePayload(payload),
  };
});

app.get('/api/play/:movieId/:episodeId', async (request) => {
  const { movieId, episodeId } = request.params;
  const server = Number.parseInt(String(request.query.server ?? 0), 10) || 0;
  const allowFallback = String(request.query.fallback ?? '1') !== '0';
  const proxyBaseUrl = getProxyBaseUrl(request);
  const playback = await getPlayback(movieId, episodeId, server, { allowFallback });
  const streamUrl =
    playback.playbackKind === 'hls'
      ? `${proxyBaseUrl}/api/hls/${movieId}/${episodeId}?server=${encodeURIComponent(
          playback.server,
        )}`
      : `${proxyBaseUrl}/api/hls/fetch?url=${encodeURIComponent(
          playback.mediaUrl,
        )}&referer=${encodeURIComponent(playback.mediaReferer || proxyBaseUrl)}`;
  return {
    ...playback,
    streamUrl,
  };
});

app.get('/api/playback/:slug', async (request) => {
  const { slug } = request.params;
  const server = Number.parseInt(String(request.query.server ?? 0), 10) || 0;
  const allowFallback = String(request.query.fallback ?? '1') !== '0';
  const detail = await getEpisodeDetail(slug);
  const proxyBaseUrl = getProxyBaseUrl(request);
  const playback = await getPlayback(detail.movie.id, detail.episode.id, server, { allowFallback });
  const streamUrl =
    playback.playbackKind === 'hls'
      ? `${proxyBaseUrl}/api/hls/${detail.movie.id}/${detail.episode.id}?server=${encodeURIComponent(
          playback.server,
        )}`
      : `${proxyBaseUrl}/api/hls/fetch?url=${encodeURIComponent(
          playback.mediaUrl,
        )}&referer=${encodeURIComponent(playback.mediaReferer || proxyBaseUrl)}`;
  return {
    ...playback,
    streamUrl,
  };
});

app.get('/api/hls/:movieId/:episodeId', async (request, reply) => {
  const { movieId, episodeId } = request.params;
  const server = Number.parseInt(String(request.query.server ?? 0), 10) || 0;
  const proxyBaseUrl = getProxyBaseUrl(request);
  const manifest = await getPlaybackManifest(movieId, episodeId, server, proxyBaseUrl);

  if (manifest.playbackKind !== 'hls' || !manifest.playlistText) {
    const response = await proxyBinaryUrl(manifest.mediaUrl, manifest.mediaReferer || proxyBaseUrl);
    if (response.statusCode >= 400) {
      reply.status(response.statusCode);
      return { error: 'upstream_error', status: response.statusCode };
    }

    reply.header('content-type', response.headers['content-type'] || 'application/octet-stream');
    reply.header('cache-control', 'public, max-age=300');
    return reply.send(response.body);
  }

  reply.type('application/vnd.apple.mpegurl; charset=utf-8');
  return rewritePlaylist(manifest.playlistText, {
    playlistUrl: manifest.mediaUrl,
    proxyBaseUrl,
  });
});

app.get('/api/hls/fetch', async (request, reply) => {
  const targetUrl = String(request.query.url || '').trim();
  const referer = String(request.query.referer || '').trim();
  if (!targetUrl) {
    reply.status(400);
    return { error: 'missing_url' };
  }

  if (/\.m3u8(\?|$)/i.test(targetUrl)) {
    const proxyBaseUrl = getProxyBaseUrl(request);
    const playlistText = await fetchText(targetUrl, {
      referer: referer || undefined,
    });

    reply.type('application/vnd.apple.mpegurl; charset=utf-8');
    reply.header('cache-control', 'public, max-age=120');
    return rewritePlaylist(playlistText, {
      playlistUrl: targetUrl,
      proxyBaseUrl,
    });
  }

  const response = await proxyBinaryUrl(targetUrl, referer || undefined);

  if (response.statusCode >= 400) {
    reply.status(response.statusCode);
    return { error: 'upstream_error', status: response.statusCode };
  }

  reply.header('content-type', response.headers['content-type'] || 'application/octet-stream');
  reply.header('cache-control', 'public, max-age=300');
  return reply.send(response.body);
});

await refreshCatalogSafely();
const catalogTimer = setInterval(() => {
  void refreshCatalogSafely();
}, 60 * 60 * 1000);
catalogTimer.unref?.();

app.setErrorHandler((error, _request, reply) => {
  app.log.error(error);
  reply.status(500).send({
    error: 'internal_error',
    message: error.message,
  });
});

const start = async () => {
  const address = await app.listen({ port: CONFIG.port, host: '0.0.0.0' });
  app.log.info(`Motchill backend listening at ${address}`);
};

start().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
