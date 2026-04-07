import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CACHE_FILE = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../data/cache.json',
);
const DEFAULT_TTL_MS = 30_000;

const memoryCache = new Map();
let flushTimer = null;
let flushPromise = null;

function serializeEntry(entry) {
  return {
    value: entry.value,
    expiresAt: entry.expiresAt,
    savedAt: entry.savedAt,
  };
}

function deserializeEntry(entry) {
  if (!entry || typeof entry !== 'object') return null;
  const expiresAt = Number(entry.expiresAt);
  if (!Number.isFinite(expiresAt)) return null;
  return {
    value: entry.value,
    expiresAt,
    savedAt: typeof entry.savedAt === 'string' ? entry.savedAt : new Date().toISOString(),
  };
}

async function loadCache() {
  try {
    const content = await readFile(CACHE_FILE, 'utf8');
    const parsed = JSON.parse(content);
    const entries = parsed.entries && typeof parsed.entries === 'object' ? parsed.entries : {};
    for (const [key, rawEntry] of Object.entries(entries)) {
      const entry = deserializeEntry(rawEntry);
      if (entry) memoryCache.set(key, entry);
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      console.warn('[motchill] failed to load cache snapshot:', error);
    }
  }
}

async function flushCache() {
  if (flushPromise) return flushPromise;

  flushPromise = (async () => {
    const payload = {
      version: 1,
      updatedAt: new Date().toISOString(),
      entries: Object.fromEntries(
        Array.from(memoryCache.entries(), ([key, entry]) => [key, serializeEntry(entry)]),
      ),
    };

    await mkdir(path.dirname(CACHE_FILE), { recursive: true });
    const tmpFile = `${CACHE_FILE}.tmp`;
    await writeFile(tmpFile, JSON.stringify(payload, null, 2), 'utf8');
    await rename(tmpFile, CACHE_FILE);
  })().finally(() => {
    flushPromise = null;
  });

  return flushPromise;
}

function scheduleFlush() {
  if (flushTimer) clearTimeout(flushTimer);
  flushTimer = setTimeout(() => {
    void flushCache().catch((error) => {
      console.warn('[motchill] failed to persist cache snapshot:', error);
    });
  }, 250);
  flushTimer.unref?.();
}

await loadCache();

export function getCached(key, { allowStale = false } = {}) {
  const entry = memoryCache.get(key);
  if (!entry) return null;
  if (!allowStale && entry.expiresAt <= Date.now()) {
    memoryCache.delete(key);
    return null;
  }
  return entry.value;
}

export function setCached(key, value, ttlMs = DEFAULT_TTL_MS) {
  memoryCache.set(key, {
    value,
    expiresAt: Date.now() + ttlMs,
    savedAt: new Date().toISOString(),
  });
  scheduleFlush();
  return value;
}

export function listCachedValues(prefix = '') {
  return Array.from(memoryCache.entries())
    .filter(([key, entry]) => key.startsWith(prefix) && entry.expiresAt > Date.now())
    .map(([, entry]) => entry.value);
}

export async function persistCache() {
  await flushCache();
}

