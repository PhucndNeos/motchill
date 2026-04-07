import * as cheerio from 'cheerio';
import CryptoJS from 'crypto-js';
import { CONFIG } from './config.js';
import { getCached, listCachedValues, setCached } from './catalog-cache.js';

const CATALOG_TTL_MS = 2 * 60 * 60 * 1000;
const DETAIL_TTL_MS = 2 * 60 * 60 * 1000;
const EPISODE_TTL_MS = 2 * 60 * 60 * 1000;
const PLAYBACK_TTL_MS = 5 * 60 * 1000;

function buildUrl(path) {
  return new URL(path, CONFIG.baseUrl).toString();
}

export async function fetchText(path, { referer } = {}) {
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Codex Motchill Backend)',
    Accept: 'text/html,application/json;q=0.9,*/*;q=0.8',
  };

  if (referer) headers.Referer = referer;

  const response = await fetch(buildUrl(path), { headers });
  if (!response.ok) {
    throw new Error(`Request failed (${response.status}) for ${path}`);
  }

  return response.text();
}

async function fetchJson(path, { referer } = {}) {
  const text = await fetchText(path, { referer });
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON from ${path}`);
  }
}

export function decryptSourcePayload(ciphertext) {
  const plain = CryptoJS.AES.decrypt(ciphertext, CONFIG.playerKey).toString(
    CryptoJS.enc.Utf8,
  );

  if (!plain) {
    throw new Error('Failed to decrypt source payload');
  }

  return JSON.parse(plain);
}

function parseTrackList(value, baseUrl = CONFIG.baseUrl) {
  if (!value) return [];

  if (Array.isArray(value)) {
    return value
      .map((track) => {
        if (!track || typeof track !== 'object') return null;
        const normalized = { ...track };
        for (const key of ['file', 'src', 'url', 'playlist', 'source']) {
          if (typeof normalized[key] === 'string') {
            const resolved = normalizePlayableCandidate(normalized[key], baseUrl);
            if (resolved) normalized[key] = resolved;
          }
        }
        return normalized;
      })
      .filter(Boolean);
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];
    try {
      const parsed = JSON.parse(trimmed);
      return parseTrackList(parsed, baseUrl);
    } catch {
      return [];
    }
  }

  return [];
}

function parseSubtitleUrl(value, baseUrl = CONFIG.baseUrl) {
  const normalized = normalizePlayableCandidate(value, baseUrl);
  return normalized && !normalized.toLowerCase().endsWith('.m3u8') ? normalized : normalized;
}

function formatSourceLabel(source, index) {
  const label =
    source?.ServerName ||
    source?.serverName ||
    source?.name ||
    source?.label ||
    source?.title ||
    source?.LinkName ||
    source?.linkName ||
    source?.Quality ||
    source?.quality;

  const text = normalizeText(label);
  return text || `Source ${index + 1}`;
}

function isTruthyValue(value) {
  return value === true || value === 1 || value === '1' || value === 'true' || value === 'yes';
}

function normalizeSourceId(source) {
  const raw = source?.SourceId ?? source?.sourceId ?? source?.Id ?? source?.id;
  const parsed = Number.parseInt(String(raw ?? ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

export function decryptWebSourcePayload(ciphertext) {
  const plain = CryptoJS.AES.decrypt(
    {
      ciphertext: CryptoJS.enc.Base64.parse(String(ciphertext).trim()),
    },
    CryptoJS.enc.Utf8.parse(CONFIG.webSourceKey),
    {
      iv: CryptoJS.enc.Utf8.parse(CONFIG.webSourceIv),
      mode: CryptoJS.mode.CBC,
      padding: CryptoJS.pad.Pkcs7,
    },
  ).toString(CryptoJS.enc.Utf8);

  if (!plain) {
    throw new Error('Failed to decrypt web source payload');
  }

  return JSON.parse(plain);
}

async function fetchWebSourcePayload(sourceId) {
  const cacheKey = `web-source:${sourceId}`;
  const cached = getCached(cacheKey);
  if (cached) return cached;

  const payload = await fetchText(`/api/source/${encodeURIComponent(sourceId)}`, {
    referer: `${CONFIG.baseUrl}/`,
  });
  const source = decryptWebSourcePayload(payload);
  return setCached(
    cacheKey,
    {
      ...source,
      sourceId,
      refreshedAt: new Date().toISOString(),
    },
    PLAYBACK_TTL_MS,
  );
}

function normalizeText(value) {
  return typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';
}

function absoluteUrl(value) {
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith('//')) return `https:${value}`;
  return buildUrl(value);
}

function resolveUrl(value, baseUrl) {
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;
  return new URL(value, baseUrl).toString();
}

function isDirectPlayableUrl(url) {
  return /\.(m3u8|mp4)(\?|$)/i.test(url);
}

function normalizePlayableCandidate(value, baseUrl) {
  if (!value) return '';
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  if (!trimmed) return '';
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  if (trimmed.startsWith('//')) return `https:${trimmed}`;
  if (trimmed.startsWith('/') || trimmed.startsWith('./') || trimmed.startsWith('../')) {
    return resolveUrl(trimmed, baseUrl);
  }
  if (isDirectPlayableUrl(trimmed)) {
    return resolveUrl(trimmed, baseUrl);
  }
  return '';
}

function extractPlayableUrlFromText(text, baseUrl) {
  if (!text) return '';
  const patterns = [
    /https?:\/\/[^"'`\s<>]+?\.(?:m3u8|mp4)(?:\?[^"'`\s<>]*)?/gi,
    /\/\/[^"'`\s<>]+?\.(?:m3u8|mp4)(?:\?[^"'`\s<>]*)?/gi,
    /(?:\.{1,2}\/|\/)[^"'`\s<>]+?\.(?:m3u8|mp4)(?:\?[^"'`\s<>]*)?/gi,
  ];

  for (const pattern of patterns) {
    const matches = String(text).match(pattern);
    if (matches?.length) {
      for (const match of matches) {
        const resolved = normalizePlayableCandidate(match, baseUrl);
        if (resolved) return resolved;
      }
    }
  }

  return '';
}

async function probeBinaryUrl(targetUrl, referer) {
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Codex Motchill Backend)',
    Accept: '*/*',
  };

  if (referer) {
    headers.Referer = referer;
    headers.Origin = new URL(referer).origin;
  }

  const response = await fetch(targetUrl, { headers, redirect: 'follow' });
  return {
    ok: response.ok,
    status: response.status,
  };
}

async function validateHlsPlaylist(mediaUrl, referer) {
  const playlistText = await fetchText(mediaUrl, { referer: referer || undefined });
  const lines = playlistText.split(/\r?\n/);
  const segmentUrls = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const resolved = normalizePlayableCandidate(trimmed, mediaUrl);
    if (resolved) segmentUrls.push(resolved);
    if (segmentUrls.length >= 3) break;
  }

  if (!segmentUrls.length) {
    return false;
  }

  for (const segmentUrl of segmentUrls) {
    const response = await probeBinaryUrl(segmentUrl, mediaUrl);
    if (!response.ok) {
      return false;
    }
  }

  return true;
}

async function resolvePlayableUrl(candidateUrl, { referer, depth = 0 } = {}) {
  if (!candidateUrl) return null;
  if (depth > 2) return null;

  const direct = normalizePlayableCandidate(candidateUrl, referer || candidateUrl);
  if (direct && isDirectPlayableUrl(direct)) {
    return {
      url: direct,
      referer: referer || direct,
      kind: direct.toLowerCase().includes('.m3u8') ? 'hls' : 'file',
    };
  }

  const pageUrl = normalizePlayableCandidate(candidateUrl, referer || candidateUrl);
  if (!pageUrl) return null;

  const pageText = await fetchText(pageUrl, { referer: referer || undefined });
  const nestedUrl = extractPlayableUrlFromText(pageText, pageUrl);
  if (!nestedUrl) return null;

  return resolvePlayableUrl(nestedUrl, { referer: pageUrl, depth: depth + 1 });
}

export async function resolvePlaybackSource(source, index, { allowFallback = true } = {}) {
  const label = formatSourceLabel(source, index);
  const sourceId = normalizeSourceId(source);
  let payload = source;
  let sourceReferer = CONFIG.baseUrl;
  let sourceResolutionError = null;

  if (sourceId > 0) {
    try {
      payload = await fetchWebSourcePayload(sourceId);
    } catch (error) {
      sourceResolutionError = error.message;
      payload = source;
    }

    sourceReferer = `${CONFIG.baseUrl}/embed/${sourceId}`;
  } else if (typeof source?.Link === 'string' && /embed\.vixos\.store\/embed\/\d+/i.test(source.Link)) {
    try {
      const match = source.Link.match(/embed\.vixos\.store\/embed\/(\d+)/i);
      if (match) {
        payload = await fetchWebSourcePayload(Number.parseInt(match[1], 10));
        sourceReferer = source.Link;
      }
    } catch {
      payload = source;
      sourceReferer = source.Link;
    }
  }

  const tracksBaseUrl = sourceReferer || payload?.Link || source?.Link || CONFIG.baseUrl;
  const tracks = parseTrackList(payload?.Tracks || source?.Tracks, tracksBaseUrl);
  const subtitleUrl = parseSubtitleUrl(
    payload?.SubLink || payload?.Subtitle || source?.SubLink || source?.Subtitle || '',
    sourceReferer || payload?.Link || source?.Link || CONFIG.baseUrl,
  );
  const isFrame = isTruthyValue(payload?.IsFrame ?? payload?.IsIframe ?? source?.IsFrame ?? source?.IsIframe);
  const quality = payload?.Quality ?? source?.Quality ?? null;
  const directCandidate =
    selectPlayableStreamUrl(payload) ||
    extractFallbackUrl(payload) ||
    normalizePlayableCandidate(payload?.Link || source?.Link || '', sourceReferer);

  const resolved = await resolvePlayableUrl(directCandidate, {
    referer: sourceReferer,
  });

  if (!resolved?.url) {
    return {
      index,
      sourceId,
      label,
      available: false,
      playbackKind: 'unsupported',
      mediaUrl: '',
      mediaReferer: sourceReferer,
      streamUrl: '',
      subtitleUrl,
      tracks,
      isFrame,
      quality,
      raw: payload,
      error: sourceResolutionError || (allowFallback ? 'Unable to resolve playable stream' : 'Source unavailable'),
    };
  }

  if (resolved.kind === 'hls') {
    try {
      const valid = await validateHlsPlaylist(resolved.url, resolved.referer);
      if (!valid) {
        return {
          index,
          sourceId,
          label,
          available: false,
          playbackKind: 'unsupported',
          mediaUrl: '',
          mediaReferer: sourceReferer,
          streamUrl: '',
          subtitleUrl,
          tracks,
          isFrame,
          quality,
          raw: payload,
          error: 'HLS segments returned an error',
        };
      }
    } catch (error) {
      return {
        index,
        sourceId,
        label,
        available: false,
        playbackKind: 'unsupported',
        mediaUrl: '',
        mediaReferer: sourceReferer,
        streamUrl: '',
        subtitleUrl,
        tracks,
        isFrame,
        quality,
        raw: payload,
        error: error.message,
      };
    }
  }

  return {
    index,
    sourceId,
    label,
    available: true,
    playbackKind: resolved.kind,
    mediaUrl: resolved.url,
    mediaReferer: resolved.referer,
    streamUrl: '',
    subtitleUrl,
    tracks,
    isFrame,
    quality,
    raw: payload,
    error: null,
  };
}

function extractCardData($, element) {
  const root = $(element);
  const linkEl = root.find('a[href]').first();
  const titleEl = root.find('h3').first();
  const subtitleEl = root.find('span').filter((_, el) => normalizeText($(el).text())).first();
  const imageEl = root.find('img').first();
  const badgeEl = root.find('span').filter((_, el) => normalizeText($(el).text())).last();

  const href = linkEl.attr('href') || '';
  const slug = href.startsWith('/') ? href.slice(1) : href;
  const title = normalizeText(titleEl.text());
  const subtitle = normalizeText(subtitleEl.text());
  const image = absoluteUrl(imageEl.attr('src') || imageEl.attr('data-src') || '');
  const badge = normalizeText(badgeEl.text());

  if (!slug || !title) return null;

  return {
    slug,
    title,
    subtitle,
    image,
    badge: badge || null,
    href: absoluteUrl(href),
  };
}

function parseCardList(html) {
  const $ = cheerio.load(html);
  const cards = [];
  $('article').each((_, element) => {
    const card = extractCardData($, element);
    if (card) cards.push(card);
  });
  return cards;
}

function parseMeta($, selector, attribute = 'content') {
  const value = $(selector).first().attr(attribute);
  return typeof value === 'string' ? value.trim() : '';
}

export function rewritePlaylist(playlistText, { playlistUrl, proxyBaseUrl }) {
  const lines = String(playlistText).split(/\r?\n/);
  return lines
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return line;

      const resolvedUrl = resolveUrl(trimmed, playlistUrl);
      const referer = encodeURIComponent(playlistUrl);
      return `${proxyBaseUrl}/api/hls/fetch?url=${encodeURIComponent(resolvedUrl)}&referer=${referer}`;
    })
    .join('\n');
}

function parseMovieDetail(html, slug) {
  const $ = cheerio.load(html);
  const h1 = normalizeText($('h1').first().text());
  const h2 = normalizeText($('h2').first().text());
  const banner = parseMeta($, 'meta[property="og:image"]');
  const description =
    parseMeta($, 'meta[name="description"]') || parseMeta($, 'meta[property="og:description"]');
  const releaseDate = parseMeta($, 'meta[name="video:release_date"]');
  const rating = parseMeta($, 'meta[property="og:rating"]');

  const episodes = [];
  const bySlug = new Map();
  $('a[href^="/xem-phim-"]').each((_, element) => {
    const href = $(element).attr('href') || '';
    const apiSlug = href.replace(/^\/xem-phim-/, '');
    const label = normalizeText($(element).text());
    const isActionLink = label.toLowerCase() === 'xem ngay';
    const episodeMatch = label.match(/tập\s*(\d+)/i);

    if (!apiSlug) return;
    if (!bySlug.has(apiSlug)) {
      bySlug.set(apiSlug, {
        id: null,
        number: episodeMatch ? Number.parseInt(episodeMatch[1], 10) || null : null,
        status: null,
        productId: null,
        name: label || apiSlug,
        slug: apiSlug,
        seoName: isActionLink ? null : (label || null),
        seoTitle: null,
        seoDescription: null,
        createdAt: null,
        updatedAt: null,
      });
      return;
    }

    const existing = bySlug.get(apiSlug);
    if (existing && existing.name.toLowerCase() === 'xem ngay' && !isActionLink) {
      bySlug.set(apiSlug, {
        ...existing,
        number: episodeMatch ? Number.parseInt(episodeMatch[1], 10) || existing.number : existing.number,
        name: label,
        seoName: label,
      });
    }
  });

  for (const episode of bySlug.values()) {
    episodes.push({
      id: null,
      number: episode.number,
      status: null,
      productId: null,
      name: episode.name,
      slug: episode.slug,
      seoName: episode.seoName,
      seoTitle: null,
      seoDescription: null,
      createdAt: null,
      updatedAt: null,
    });
  }

  const movie = {
    id: null,
    name: h1 || h2 || slug,
    otherName: h2 || null,
    rating: rating ? Number.parseFloat(rating) || null : null,
    ratingCount: null,
    thumbnail: banner,
    banner,
    description,
    episodeTotal: episodes.length || null,
    year: null,
    slug,
    originalSlug: slug,
    duration: null,
    publish: null,
    type: null,
    statusTitle: null,
    statusText: null,
    countries: [],
    categories: [],
    releaseDate,
  };

  return {
    movie,
    episode: episodes[0] || {
      id: null,
      number: 1,
      status: null,
      productId: null,
      name: 'Episode 1',
      slug: `${slug}-tap-1`,
      seoName: 'Episode 1',
      seoTitle: null,
      seoDescription: null,
      createdAt: null,
      updatedAt: null,
    },
    episodes,
    sources: [],
  };
}

function extractSourceUrl(value) {
  if (!value) return null;
  if (typeof value === 'string') {
    if (/^https?:\/\//i.test(value)) return value;
    if (/\.m3u8(\?|$)/i.test(value) || /\.mp4(\?|$)/i.test(value)) return value;
    return null;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = extractSourceUrl(item);
      if (found) return found;
    }
    return null;
  }

  if (typeof value === 'object') {
    for (const key of ['file', 'url', 'src', 'playlist', 'source', 'streamUrl']) {
      const found = extractSourceUrl(value[key]);
      if (found) return found;
    }

    for (const nested of Object.values(value)) {
      const found = extractSourceUrl(nested);
      if (found) return found;
    }
  }

  return null;
}

function scorePlaybackCandidate({ url, serverName = '' }) {
  let score = 0;
  let host = '';

  try {
    const parsed = new URL(url);
    host = parsed.host.toLowerCase();
    if (parsed.pathname.toLowerCase().endsWith('.m3u8')) score += 40;
    if (parsed.pathname.toLowerCase().endsWith('.mp4')) score += 30;
  } catch {
    return -1;
  }

  if (host.includes('opstream')) score += 50;
  if (host.includes('streamc')) score += 20;
  if (host.includes('vixos')) score += 15;
  if (host.includes('tiktokcdn')) score -= 100;
  if (host.includes('embed')) score -= 20;
  if (/vietsub/i.test(serverName)) score += 5;
  if (/thuyết minh|thuyet minh/i.test(serverName)) score += 5;

  return score;
}

export function selectPlayableStreamUrl(value) {
  const candidates = [];

  const visit = (node, serverName = '') => {
    if (!node) return;

    if (Array.isArray(node)) {
      for (const item of node) {
        visit(item, serverName);
      }
      return;
    }

    if (typeof node === 'string') {
      if (isDirectPlayableUrl(node)) {
        candidates.push({ url: node, serverName });
      }
      return;
    }

    if (typeof node === 'object') {
      const nextServerName = normalizeText(node.ServerName || node.serverName || node.name || serverName);
      for (const key of ['Link', 'link', 'url', 'src', 'streamUrl', 'file', 'playlist', 'source']) {
        const found = node[key];
        if (typeof found === 'string' && /^https?:\/\//i.test(found) && isDirectPlayableUrl(found)) {
          candidates.push({ url: found, serverName: nextServerName });
        }
      }

      for (const nested of Object.values(node)) {
        visit(nested, nextServerName);
      }
    }
  };

  visit(value);

  if (!candidates.length) {
    return extractSourceUrl(value);
  }

  candidates.sort((a, b) => scorePlaybackCandidate(b) - scorePlaybackCandidate(a));
  return candidates[0]?.url || extractSourceUrl(value);
}

export function selectPlaybackSource(value, server = 0) {
  const sources = Array.isArray(value) ? value : Array.isArray(value?.sources) ? value.sources : [];
  if (!sources.length) return value;

  const index = Number.isFinite(server) ? Math.max(0, Math.min(Math.trunc(server), sources.length - 1)) : 0;
  return sources[index] ?? sources[0];
}

export function extractFallbackUrl(value) {
  if (!value) return null;

  if (typeof value === 'string') {
    if (!/^https?:\/\//i.test(value)) return null;
    if (/(embed\.vixos\.store\/embed\/|embed\d+\.streamc\.xyz\/embed\.php)/i.test(value)) {
      return value;
    }
    return null;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = extractFallbackUrl(item);
      if (found) return found;
    }
    return null;
  }

  if (typeof value === 'object') {
    for (const key of ['fallbackUrl', 'webUrl', 'embedUrl', 'pageUrl', 'url', 'src', 'link']) {
      const found = extractFallbackUrl(value[key]);
      if (found) return found;
    }

    for (const nested of Object.values(value)) {
      const found = extractFallbackUrl(nested);
      if (found) return found;
    }
  }

  return null;
}

function normalizeEpisode(episode) {
  return {
    id: episode.Id,
    number: episode.EpisodeNumber,
    status: episode.Status,
    productId: episode.ProductId,
    name: episode.Name,
    slug: episode.FullLink || episode.Link || '',
    seoName: episode.SeoName || null,
    seoTitle: episode.SeoTitle || null,
    seoDescription: episode.SeoDescription || null,
    createdAt: episode.CreateOn || null,
    updatedAt: episode.UpdateOnRaw || episode.UpdateOn || null,
  };
}

function normalizeMovie(movie) {
  return {
    id: movie.Id,
    name: movie.Name,
    otherName: movie.OtherName || null,
    rating: movie.RatePoint ?? null,
    ratingCount: movie.RateNumner ?? null,
    thumbnail: absoluteUrl(movie.AvatarImageThumb),
    banner: absoluteUrl(movie.Banner),
    description: normalizeText(movie.Description),
    episodeTotal: movie.EpisodesTotal ?? null,
    year: movie.Year ?? null,
    slug: movie.Link,
    originalSlug: movie.OriginalLink || movie.Link,
    duration: movie.Time || null,
    publish: movie.IsPublish ?? null,
    type: movie.TypeRaw || null,
    statusTitle: movie.StatusTitle || null,
    statusText: movie.StatusTMText || null,
    countries: Array.isArray(movie.Countries)
      ? movie.Countries.map((country) => ({
          id: country.Id,
          name: country.Name,
          slug: country.Link,
        }))
      : [],
    categories: Array.isArray(movie.Categories)
      ? movie.Categories.map((category) => ({
          id: category.Id,
          name: category.Name,
          slug: category.Link,
        }))
      : [],
  };
}

function movieDetailToCard(detail) {
  if (!detail?.movie?.slug) return null;
  return {
    slug: detail.movie.slug,
    title: detail.movie.name || detail.movie.slug,
    subtitle: detail.movie.otherName || detail.movie.year?.toString?.() || '',
    image: detail.movie.banner || detail.movie.thumbnail || '',
    badge: detail.movie.statusTitle || detail.movie.statusText || null,
    href: buildUrl(`/${detail.movie.slug}`),
  };
}

function searchCachedCatalogCards(query) {
  const normalized = query.toLowerCase();
  const matches = [];
  const seen = new Set();

  for (const entry of listCachedValues()) {
    if (Array.isArray(entry?.cards)) {
      for (const card of entry.cards) {
        const haystack = [card.title, card.subtitle, card.slug, card.badge]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        if (!haystack.includes(normalized) || seen.has(card.slug)) continue;
        seen.add(card.slug);
        matches.push(card);
      }
    }

    const card = movieDetailToCard(entry);
    if (card) {
      const detailHaystack = [
        card.title,
        card.subtitle,
        entry.movie?.description,
        card.slug,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      if (detailHaystack.includes(normalized) && !seen.has(card.slug)) {
        seen.add(card.slug);
        matches.push(card);
      }
    }
  }

  return matches;
}

export async function refreshCatalogSnapshot({ limit = 24 } = {}) {
  const home = await getHome({ forceRefresh: true });
  const slugs = home.cards
    .map((card) => card.slug)
    .filter((slug, index, array) => slug && array.indexOf(slug) === index)
    .slice(0, limit);

  const refreshedMovies = [];
  for (const slug of slugs) {
    try {
      refreshedMovies.push(await getMovieDetail(slug, { forceRefresh: true }));
    } catch (error) {
      console.warn('[motchill] catalog refresh failed for movie', slug, error);
    }
  }

  return {
    home,
    moviesRefreshed: refreshedMovies.length,
    refreshedAt: new Date().toISOString(),
  };
}

export async function getHome({ forceRefresh = false } = {}) {
  const cached = getCached('home', { allowStale: !forceRefresh });
  if (cached && !forceRefresh) return cached;

  const html = await fetchText('/', { referer: CONFIG.baseUrl });
  return setCached('home', {
    source: CONFIG.baseUrl,
    cards: parseCardList(html),
    refreshedAt: new Date().toISOString(),
  }, CATALOG_TTL_MS);
}

export async function searchMovies(query, { forceRefresh = false } = {}) {
  const cacheKey = `search:${query.toLowerCase()}`;
  const cached = getCached(cacheKey, { allowStale: !forceRefresh });
  if (cached && !forceRefresh) return cached;

  const localMatches = searchCachedCatalogCards(query);
  if (localMatches.length && !forceRefresh) {
    return setCached(
      cacheKey,
      {
        query,
        cards: localMatches,
        source: 'catalog-cache',
        refreshedAt: new Date().toISOString(),
      },
      CATALOG_TTL_MS,
    );
  }

  const html = await fetchText(`/search?searchtext=${encodeURIComponent(query)}`, {
    referer: buildUrl('/'),
  });
  return setCached(cacheKey, {
    query,
    cards: parseCardList(html),
    source: CONFIG.baseUrl,
    refreshedAt: new Date().toISOString(),
  }, CATALOG_TTL_MS);
}

export async function getEpisodeDetail(slug, { forceRefresh = false } = {}) {
  const cacheKey = `episode:${slug}`;
  const cached = getCached(cacheKey, { allowStale: !forceRefresh });
  if (cached && !forceRefresh) return cached;

  const data = await fetchJson(`/api/episode/${encodeURIComponent(slug)}`, {
    referer: buildUrl(`/${slug}`),
  });

  const decryptedSources = [];

  if (Array.isArray(data.sources)) {
    for (const sourceGroup of data.sources) {
      if (typeof sourceGroup === 'string' && sourceGroup.startsWith('U2FsdGVkX1')) {
        try {
          const payload = decryptSourcePayload(sourceGroup);
          decryptedSources.push(payload);
        } catch {
          decryptedSources.push({ encrypted: sourceGroup });
        }
      } else if (sourceGroup && typeof sourceGroup === 'object') {
        decryptedSources.push(sourceGroup);
      }
    }
  }

  return setCached(cacheKey, {
    movie: normalizeMovie(data.movie),
    episode: normalizeEpisode(data.episode),
    episodes: Array.isArray(data.episodeAll) ? data.episodeAll.map(normalizeEpisode) : [],
    sources: decryptedSources,
    refreshedAt: new Date().toISOString(),
  }, EPISODE_TTL_MS);
}

export async function getMovieDetail(slug, { forceRefresh = false } = {}) {
  const cacheKey = `movie:${slug}`;
  const cached = getCached(cacheKey, { allowStale: !forceRefresh });
  if (cached && !forceRefresh) return cached;

  const html = await fetchText(`/${encodeURIComponent(slug)}`, {
    referer: buildUrl('/'),
  });

  return setCached(
    cacheKey,
    {
      ...parseMovieDetail(html, slug),
      refreshedAt: new Date().toISOString(),
    },
    DETAIL_TTL_MS,
  );
}

async function resolvePlaybackSources(sources, server = 0, { allowFallback = true } = {}) {
  const normalizedSources = [];
  for (const [index, source] of sources.entries()) {
    normalizedSources.push(await resolvePlaybackSource(source, index, { allowFallback }));
  }

  const requestedIndex = Number.isFinite(server) ? Math.max(0, Math.min(Math.trunc(server), normalizedSources.length - 1)) : 0;
  const requested = normalizedSources[requestedIndex];

  if (requested?.available) {
    return {
      selectedSource: requested,
      sources: normalizedSources,
    };
  }

  if (allowFallback) {
    const fallback = normalizedSources.find((item) => item.available);
    if (fallback) {
      return {
        selectedSource: fallback,
        sources: normalizedSources,
      };
    }
  }

  return {
    selectedSource: requested || normalizedSources[0] || null,
    sources: normalizedSources,
  };
}

export async function getPlayback(movieId, episodeId, server = 0, { forceRefresh = true, allowFallback = true } = {}) {
  const cacheKey = `play:${movieId}:${episodeId}:${server}:${allowFallback ? 'fallback' : 'strict'}`;
  const freshCached = getCached(cacheKey);
  const staleCached = getCached(cacheKey, { allowStale: true });
  if (freshCached && !forceRefresh) return freshCached;
  if (!forceRefresh && staleCached) return staleCached;

  try {
    const payload = await fetchText(
      `/api/play/get?movieId=${encodeURIComponent(movieId)}&episodeId=${encodeURIComponent(
        episodeId,
      )}&server=${encodeURIComponent(server)}`,
      {
        referer: buildUrl('/'),
      },
    );

    const decrypted = decryptSourcePayload(payload.trim());
    const sources = Array.isArray(decrypted) ? decrypted : [];
    const { selectedSource, sources: resolvedSources } = await resolvePlaybackSources(sources, server, {
      allowFallback,
    });

    if (!selectedSource?.available) {
      throw new Error('Unable to resolve playable stream');
    }

    return setCached(
      cacheKey,
      {
        movieId,
        episodeId,
        server: selectedSource.index,
        requestedServer: server,
        playbackKind: selectedSource.playbackKind,
        mediaUrl: selectedSource.mediaUrl,
        mediaReferer: selectedSource.mediaReferer,
        subtitleUrl: selectedSource.subtitleUrl,
        tracks: selectedSource.tracks,
        sources: resolvedSources,
        raw: decrypted,
        selectedSource,
        refreshedAt: new Date().toISOString(),
      },
      PLAYBACK_TTL_MS,
    );
  } catch (error) {
    if (staleCached) return staleCached;
    throw error;
  }
}

export function getPlaybackKind(playback) {
  return playback?.playbackKind || 'unsupported';
}

export async function getPlaybackManifest(movieId, episodeId, server = 0, proxyBaseUrl, { allowFallback = true } = {}) {
  const playback = await getPlayback(movieId, episodeId, server, { allowFallback });
  if (playback.playbackKind !== 'hls') {
    return {
      ...playback,
      proxyStreamUrl: `${proxyBaseUrl}/api/hls/fetch?url=${encodeURIComponent(
        playback.mediaUrl,
      )}&referer=${encodeURIComponent(playback.mediaReferer || buildUrl('/'))}`,
      playlistText: null,
    };
  }

  const playlistText = await fetchText(playback.mediaUrl, {
    referer: playback.mediaReferer || playback.mediaUrl,
  });

  return {
    ...playback,
    proxyStreamUrl: `${proxyBaseUrl}/api/hls/${movieId}/${episodeId}?server=${encodeURIComponent(server)}`,
    playlistText,
  };
}
