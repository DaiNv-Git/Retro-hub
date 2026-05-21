const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const zlib = require('node:zlib');
const { URL } = require('node:url');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const DATA_URL =
  process.env.DATA_URL || 'https://engfordev.top/gbagame/data.json';
const APP_DATA_FILE =
  process.env.APP_DATA_FILE ||
  path.join(__dirname, 'data', 'legal-games.json');
const AD_CONFIG_FILE =
  process.env.AD_CONFIG_FILE ||
  path.join(__dirname, 'data', 'ad-config.json');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const DISCORD_URL = process.env.DISCORD_URL || 'https://discord.gg/vSh2kmcR';
const PUBLIC_BASE_URL =
  process.env.PUBLIC_BASE_URL || 'https://gbagametop.shop';
const CACHE_TTL_MS = Number(process.env.CACHE_TTL_MS || 10 * 60 * 1000);
const IMAGE_CACHE_TTL_MS = Number(
  process.env.IMAGE_CACHE_TTL_MS || 7 * 24 * 60 * 60 * 1000,
);
const IMAGE_FETCH_TIMEOUT_MS = Number(process.env.IMAGE_FETCH_TIMEOUT_MS || 8000);
const PUBLIC_DIR = path.join(__dirname, 'public');

const defaultAdConfig = {
  adsEnabled: true,
  bannerEnabled: true,
  inlineBannerEnabled: true,
  interstitialEnabled: true,
  rewardedEnabled: true,
  appOpenEnabled: true,
  actionInterstitialEnabled: true,
  discoverActionInterstitialEnabled: true,
  savedGamePlayInterstitialEnabled: true,
  importedGamePlayInterstitialEnabled: true,
  consoleActionInterstitialEnabled: true,
  downloadCompleteInterstitialEnabled: true,
  playExitInterstitialEnabled: true,
  featuredPicksRewardedEnabled: true,
  skinRewardedEnabled: true,
  inlineBannerEvery: 2,
  downloadInterstitialCooldownSeconds: 45,
  playExitInterstitialCooldownSeconds: 60,
  actionInterstitialCooldownSeconds: 60,
  appOpenColdStartCooldownMinutes: 10,
  appOpenForegroundCooldownMinutes: 5,
  appOpenBackgroundThresholdSeconds: 90,
  appOpenLaunchThreshold: 2,
  featuredUnlockMinutes: 30,
};

let publicCache = {
  fetchedAt: 0,
  games: [],
};

let appCache = {
  fetchedAt: 0,
  games: [],
};

const imageCache = new Map();

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function sendJson(res, status, body, extraHeaders = {}) {
  const payload = Buffer.from(JSON.stringify(body));
  const acceptEncoding = String(res.acceptEncoding || '');
  const shouldGzip = /\bgzip\b/.test(acceptEncoding) && payload.length > 1024;
  const responseHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': extraHeaders['Cache-Control'] || 'public, max-age=300',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token',
    ...extraHeaders,
  };
  delete responseHeaders.acceptEncoding;

  if (shouldGzip) {
    responseHeaders['Content-Encoding'] = 'gzip';
    res.writeHead(status, responseHeaders);
    res.end(zlib.gzipSync(payload));
    return;
  }

  res.writeHead(status, responseHeaders);
  res.end(payload);
}

function clampNumber(value, min, max, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.round(parsed)));
}

function normalizeAdConfig(input = {}) {
  const merged = { ...defaultAdConfig, ...input };
  return {
    adsEnabled: merged.adsEnabled !== false,
    bannerEnabled: merged.bannerEnabled !== false,
    inlineBannerEnabled: merged.inlineBannerEnabled !== false,
    interstitialEnabled: merged.interstitialEnabled !== false,
    rewardedEnabled: merged.rewardedEnabled !== false,
    appOpenEnabled: merged.appOpenEnabled !== false,
    actionInterstitialEnabled: merged.actionInterstitialEnabled !== false,
    discoverActionInterstitialEnabled:
      merged.discoverActionInterstitialEnabled !== false,
    savedGamePlayInterstitialEnabled:
      merged.savedGamePlayInterstitialEnabled !== false,
    importedGamePlayInterstitialEnabled:
      merged.importedGamePlayInterstitialEnabled !== false,
    consoleActionInterstitialEnabled:
      merged.consoleActionInterstitialEnabled !== false,
    downloadCompleteInterstitialEnabled:
      merged.downloadCompleteInterstitialEnabled !== false,
    playExitInterstitialEnabled: merged.playExitInterstitialEnabled !== false,
    featuredPicksRewardedEnabled:
      merged.featuredPicksRewardedEnabled !== false,
    skinRewardedEnabled: merged.skinRewardedEnabled !== false,
    inlineBannerEvery: clampNumber(merged.inlineBannerEvery, 0, 20, 2),
    downloadInterstitialCooldownSeconds: clampNumber(
      merged.downloadInterstitialCooldownSeconds,
      15,
      3600,
      45,
    ),
    playExitInterstitialCooldownSeconds: clampNumber(
      merged.playExitInterstitialCooldownSeconds,
      15,
      3600,
      60,
    ),
    actionInterstitialCooldownSeconds: clampNumber(
      merged.actionInterstitialCooldownSeconds,
      15,
      3600,
      60,
    ),
    appOpenColdStartCooldownMinutes: clampNumber(
      merged.appOpenColdStartCooldownMinutes,
      1,
      1440,
      10,
    ),
    appOpenForegroundCooldownMinutes: clampNumber(
      merged.appOpenForegroundCooldownMinutes,
      1,
      1440,
      5,
    ),
    appOpenBackgroundThresholdSeconds: clampNumber(
      merged.appOpenBackgroundThresholdSeconds,
      15,
      86400,
      90,
    ),
    appOpenLaunchThreshold: clampNumber(merged.appOpenLaunchThreshold, 1, 100, 2),
    featuredUnlockMinutes: clampNumber(merged.featuredUnlockMinutes, 1, 1440, 30),
  };
}

async function readJsonBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
    if (Buffer.concat(chunks).length > 64 * 1024) {
      throw new Error('Request body too large');
    }
  }
  const body = Buffer.concat(chunks).toString('utf8').trim();
  return body ? JSON.parse(body) : {};
}

async function loadAdConfig() {
  try {
    const raw = JSON.parse(await fs.readFile(AD_CONFIG_FILE, 'utf8'));
    return normalizeAdConfig(raw);
  } catch (_) {
    return { ...defaultAdConfig };
  }
}

async function saveAdConfig(config) {
  const normalized = normalizeAdConfig(config);
  await fs.mkdir(path.dirname(AD_CONFIG_FILE), { recursive: true });
  await fs.writeFile(
    AD_CONFIG_FILE,
    `${JSON.stringify(normalized, null, 2)}\n`,
    'utf8',
  );
  return normalized;
}

function isAdminAuthorized(req, url) {
  if (!ADMIN_TOKEN) return true;
  return (
    req.headers['x-admin-token'] === ADMIN_TOKEN ||
    url.searchParams.get('token') === ADMIN_TOKEN
  );
}

function sendError(res, status, message) {
  sendJson(res, status, {
    ok: false,
    error: message,
  });
}

function decodeHtml(value = '') {
  return String(value)
    .replace(/&#8211;/g, '-')
    .replace(/&#8217;/g, "'")
    .replace(/&#038;/g, '&')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function normalizeGame(item, options = {}) {
  const id = String(item.id);
  const isAppPayload = options.app === true;
  const title = decodeHtml(item.title || 'Untitled GBA Game').trim();
  const platform = decodeHtml(item.platform || 'Game Boy Advance').trim();
  const downloadUrl = item.download_link || item.downloadUrl || '';

  const thumbnail = item.thumbnail || '';
  return {
    id,
    title,
    slug: title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, ''),
    platform,
    region: decodeHtml(item.region || 'Unknown'),
    version: decodeHtml(item.version || '1.0'),
    thumbnail: proxiedImageUrl(thumbnail),
    originalThumbnail: thumbnail,
    sourceUrl: item.link || item.sourceUrl || '',
    downloadUrl: proxiedDownloadUrl(id, downloadUrl, isAppPayload),
    originalDownloadUrl: downloadUrl,
    fileName: decodeURIComponent(downloadUrl.split('/').pop() || '')
      .replace(/\+/g, ' '),
    publishedAt: item.date || '',
    license: item.license || 'Public/free distribution',
  };
}

function proxiedImageUrl(imageUrl) {
  if (!imageUrl || !/^https?:\/\//i.test(imageUrl)) return imageUrl || '';
  return `${PUBLIC_BASE_URL}/api/image?url=${encodeURIComponent(imageUrl)}`;
}

function proxiedDownloadUrl(id, downloadUrl, isAppPayload) {
  if (!downloadUrl || !/^https?:\/\//i.test(downloadUrl)) return downloadUrl || '';
  const scope = isAppPayload ? 'app/' : '';
  return `${PUBLIC_BASE_URL}/api/${scope}download/${encodeURIComponent(id)}`;
}

async function handleImageProxy(res, url) {
  const target = url.searchParams.get('url') || '';
  if (!/^https?:\/\//i.test(target)) {
    sendError(res, 400, 'Invalid image URL');
    return;
  }

  const now = Date.now();
  const cached = imageCache.get(target);
  if (cached && now - cached.fetchedAt < IMAGE_CACHE_TTL_MS) {
    res.writeHead(200, {
      'Content-Type': cached.contentType,
      'Cache-Control': 'public, max-age=604800, immutable',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(cached.body);
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), IMAGE_FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(target, {
      signal: controller.signal,
      headers: {
        accept: 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'user-agent': 'gbagametop-image-cache/1.0',
      },
    });

    if (!response.ok) {
      throw new Error(`Image source returned HTTP ${response.status}`);
    }

    const contentType = response.headers.get('content-type') || 'image/jpeg';
    if (!contentType.startsWith('image/')) {
      throw new Error('Image source did not return an image');
    }

    const body = Buffer.from(await response.arrayBuffer());
    imageCache.set(target, {
      fetchedAt: now,
      contentType,
      body,
    });

    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=604800, immutable',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(body);
  } catch (error) {
    if (cached) {
      res.writeHead(200, {
        'Content-Type': cached.contentType,
        'Cache-Control': 'public, max-age=3600',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(cached.body);
      return;
    }

    res.writeHead(302, {
      Location: target,
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
    });
    res.end();
  } finally {
    clearTimeout(timeout);
  }
}

function redirectToDownload(res, game) {
  const downloadUrl = game && (game.originalDownloadUrl || game.downloadUrl);
  if (!downloadUrl || !/^https?:\/\//i.test(downloadUrl)) {
    sendError(res, 404, 'Download not available');
    return;
  }

  res.writeHead(302, {
    Location: downloadUrl,
    'Cache-Control': 'public, max-age=300',
    'Access-Control-Allow-Origin': '*',
  });
  res.end();
}

async function loadPublicGames(force = false) {
  const now = Date.now();
  const isFresh = now - publicCache.fetchedAt < CACHE_TTL_MS;
  if (!force && publicCache.games.length && isFresh) return publicCache.games;

  const response = await fetch(DATA_URL, {
    headers: {
      accept: 'application/json',
      'user-agent': 'gbagametop-web/1.0',
    },
  });

  if (!response.ok) {
    throw new Error(`Public data source returned HTTP ${response.status}`);
  }

  const rawGames = await response.json();
  if (!Array.isArray(rawGames)) {
    throw new Error('Public data source is not a JSON array');
  }

  publicCache = {
    fetchedAt: now,
    games: rawGames.map((item) => normalizeGame(item)),
  };

  return publicCache.games;
}

async function loadAppGames(force = false) {
  const now = Date.now();
  const isFresh = now - appCache.fetchedAt < CACHE_TTL_MS;
  if (!force && appCache.games.length && isFresh) return appCache.games;

  const rawGames = JSON.parse(await fs.readFile(APP_DATA_FILE, 'utf8'));
  if (!Array.isArray(rawGames)) {
    throw new Error('App data source is not a JSON array');
  }

  appCache = {
    fetchedAt: now,
    games: rawGames.map((item) => normalizeGame(item, { app: true })),
  };

  return appCache.games;
}

function paginate(items, page, pageSize) {
  const safePage = Math.max(1, page || 1);
  const safePageSize = Math.min(100, Math.max(1, pageSize || 24));
  const start = (safePage - 1) * safePageSize;
  const data = items.slice(start, start + safePageSize);

  return {
    data,
    meta: {
      page: safePage,
      pageSize: safePageSize,
      total: items.length,
      totalPages: Math.max(1, Math.ceil(items.length / safePageSize)),
    },
  };
}

async function handleApi(req, res, url) {
  if (req.method === 'OPTIONS') {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (url.pathname === '/api/health') {
    if (req.method !== 'GET') {
      sendError(res, 405, 'Method not allowed');
      return;
    }
    sendJson(res, 200, {
      ok: true,
      service: 'gbagametop-web',
      domain: PUBLIC_BASE_URL,
    });
    return;
  }

  if (url.pathname === '/api/app/ad-config') {
    if (req.method === 'GET') {
      const config = await loadAdConfig();
      sendJson(
        res,
        200,
        {
          ok: true,
          updatedAt: new Date().toISOString(),
          config,
        },
        { 'Cache-Control': 'no-cache' },
      );
      return;
    }

    if (req.method === 'POST') {
      if (!isAdminAuthorized(req, url)) {
        sendError(res, 401, 'Unauthorized');
        return;
      }
      const body = await readJsonBody(req);
      const config = await saveAdConfig(body.config || body);
      sendJson(
        res,
        200,
        {
          ok: true,
          updatedAt: new Date().toISOString(),
          config,
        },
        { 'Cache-Control': 'no-cache' },
      );
      return;
    }

    sendError(res, 405, 'Method not allowed');
    return;
  }

  if (req.method !== 'GET') {
    sendError(res, 405, 'Method not allowed');
    return;
  }

  if (url.pathname === '/api/image') {
    await handleImageProxy(res, url);
    return;
  }

  if (url.pathname === '/api/discord') {
    if (url.searchParams.get('redirect') === '1') {
      res.writeHead(302, {
        Location: DISCORD_URL,
        'Access-Control-Allow-Origin': '*',
      });
      res.end();
      return;
    }

    sendJson(res, 200, {
      ok: true,
      discordUrl: DISCORD_URL,
    });
    return;
  }

  if (url.pathname === '/api/home') {
    const games = await loadPublicGames(url.searchParams.get('refresh') === '1');
    const featured = games.slice(0, 12);

    sendJson(res, 200, {
      ok: true,
      domain: PUBLIC_BASE_URL,
      discordUrl: DISCORD_URL,
      updatedAt: new Date(publicCache.fetchedAt).toISOString(),
      featured,
      games: games.slice(0, 24),
    });
    return;
  }

  if (url.pathname === '/api/games') {
    const games = await loadPublicGames(url.searchParams.get('refresh') === '1');
    const search = (url.searchParams.get('search') || '').trim().toLowerCase();
    const platform = (url.searchParams.get('platform') || '').trim();
    const page = Number(url.searchParams.get('page') || 1);
    const pageSize = Number(url.searchParams.get('pageSize') || 24);

    const filtered = games.filter((game) => {
      const matchesSearch =
        !search ||
        game.title.toLowerCase().includes(search) ||
        game.region.toLowerCase().includes(search);
      const matchesPlatform = !platform || game.platform === platform;
      return matchesSearch && matchesPlatform;
    });

    sendJson(res, 200, {
      ok: true,
      updatedAt: new Date(publicCache.fetchedAt).toISOString(),
      ...paginate(filtered, page, pageSize),
    });
    return;
  }

  if (url.pathname === '/api/app/home') {
    const games = await loadAppGames(url.searchParams.get('refresh') === '1');
    sendJson(res, 200, {
      ok: true,
      domain: PUBLIC_BASE_URL,
      discordUrl: DISCORD_URL,
      updatedAt: new Date(appCache.fetchedAt).toISOString(),
      featured: games.slice(0, 12),
      games: games.slice(0, 24),
    });
    return;
  }

  if (url.pathname === '/api/app/games') {
    const games = await loadAppGames(url.searchParams.get('refresh') === '1');
    const search = (url.searchParams.get('search') || '').trim().toLowerCase();
    const platform = (url.searchParams.get('platform') || '').trim();
    const page = Number(url.searchParams.get('page') || 1);
    const pageSize = Number(url.searchParams.get('pageSize') || 24);

    const filtered = games.filter((game) => {
      const matchesSearch =
        !search ||
        game.title.toLowerCase().includes(search) ||
        game.region.toLowerCase().includes(search);
      const matchesPlatform = !platform || game.platform === platform;
      return matchesSearch && matchesPlatform;
    });

    sendJson(res, 200, {
      ok: true,
      updatedAt: new Date(appCache.fetchedAt).toISOString(),
      ...paginate(filtered, page, pageSize),
    });
    return;
  }

  const publicDownloadMatch = url.pathname.match(/^\/api\/download\/([^/]+)$/);
  if (publicDownloadMatch) {
    const games = await loadPublicGames(url.searchParams.get('refresh') === '1');
    const idOrSlug = decodeURIComponent(publicDownloadMatch[1]);
    const game = games.find(
      (item) => item.id === idOrSlug || item.slug === idOrSlug,
    );
    redirectToDownload(res, game);
    return;
  }

  const appDownloadMatch = url.pathname.match(/^\/api\/app\/download\/([^/]+)$/);
  if (appDownloadMatch) {
    const games = await loadAppGames(url.searchParams.get('refresh') === '1');
    const idOrSlug = decodeURIComponent(appDownloadMatch[1]);
    const game = games.find(
      (item) => item.id === idOrSlug || item.slug === idOrSlug,
    );
    redirectToDownload(res, game);
    return;
  }

  const detailMatch = url.pathname.match(/^\/api\/games\/([^/]+)$/);
  if (detailMatch) {
    const games = await loadPublicGames(url.searchParams.get('refresh') === '1');
    const idOrSlug = decodeURIComponent(detailMatch[1]);
    const game = games.find(
      (item) => item.id === idOrSlug || item.slug === idOrSlug,
    );

    if (!game) {
      sendError(res, 404, 'Game not found');
      return;
    }

    sendJson(res, 200, {
      ok: true,
      data: game,
    });
    return;
  }

  const appDetailMatch = url.pathname.match(/^\/api\/app\/games\/([^/]+)$/);
  if (appDetailMatch) {
    const games = await loadAppGames(url.searchParams.get('refresh') === '1');
    const idOrSlug = decodeURIComponent(appDetailMatch[1]);
    const game = games.find(
      (item) => item.id === idOrSlug || item.slug === idOrSlug,
    );

    if (!game) {
      sendError(res, 404, 'Game not found');
      return;
    }

    sendJson(res, 200, {
      ok: true,
      data: game,
    });
    return;
  }

  sendError(res, 404, 'API route not found');
}

async function serveStatic(req, res, url) {
  let filePath = url.pathname === '/' ? '/index.html' : url.pathname;
  filePath = path.normalize(filePath).replace(/^(\.\.[/\\])+/, '');

  const absolutePath = path.join(PUBLIC_DIR, filePath);
  if (!absolutePath.startsWith(PUBLIC_DIR)) {
    sendError(res, 403, 'Forbidden');
    return;
  }

  try {
    const file = await fs.readFile(absolutePath);
    const extension = path.extname(absolutePath);
    res.writeHead(200, {
      'Content-Type': mimeTypes[extension] || 'application/octet-stream',
      'Cache-Control':
        extension === '.html' ? 'no-cache' : 'public, max-age=86400',
    });
    res.end(file);
  } catch (error) {
    const fallback = await fs.readFile(path.join(PUBLIC_DIR, 'index.html'));
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache',
    });
    res.end(fallback);
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  res.acceptEncoding = req.headers['accept-encoding'];

  try {
    if (url.pathname.startsWith('/api/')) {
      await handleApi(req, res, url);
      return;
    }

    await serveStatic(req, res, url);
  } catch (error) {
    sendError(res, 502, error.message || 'Unexpected server error');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`GBA Game Top running at http://${HOST}:${PORT}`);
});
