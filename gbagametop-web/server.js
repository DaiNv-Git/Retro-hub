const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { URL } = require('node:url');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const DATA_URL =
  process.env.DATA_URL || 'https://engfordev.top/gbagame/data.json';
const APP_DATA_FILE =
  process.env.APP_DATA_FILE ||
  path.join(__dirname, 'data', 'legal-games.json');
const DISCORD_URL = process.env.DISCORD_URL || 'https://discord.gg/vSh2kmcR';
const PUBLIC_BASE_URL =
  process.env.PUBLIC_BASE_URL || 'https://gbagametop.shop';
const CACHE_TTL_MS = Number(process.env.CACHE_TTL_MS || 10 * 60 * 1000);
const PUBLIC_DIR = path.join(__dirname, 'public');

let publicCache = {
  fetchedAt: 0,
  games: [],
};

let appCache = {
  fetchedAt: 0,
  games: [],
};

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
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'public, max-age=60',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    ...extraHeaders,
  });
  res.end(payload);
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

function normalizeGame(item) {
  const title = decodeHtml(item.title || 'Untitled GBA Game').trim();
  const platform = decodeHtml(item.platform || 'Game Boy Advance').trim();
  const downloadUrl = item.download_link || item.downloadUrl || '';

  return {
    id: String(item.id),
    title,
    slug: title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, ''),
    platform,
    region: decodeHtml(item.region || 'Unknown'),
    version: decodeHtml(item.version || '1.0'),
    thumbnail: item.thumbnail || '',
    sourceUrl: item.link || item.sourceUrl || '',
    downloadUrl,
    fileName: decodeURIComponent(downloadUrl.split('/').pop() || '')
      .replace(/\+/g, ' '),
    publishedAt: item.date || '',
    license: item.license || 'Public/free distribution',
  };
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
    games: rawGames.map(normalizeGame),
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
    games: rawGames.map(normalizeGame),
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

  if (req.method !== 'GET') {
    sendError(res, 405, 'Method not allowed');
    return;
  }

  if (url.pathname === '/api/health') {
    sendJson(res, 200, {
      ok: true,
      service: 'gbagametop-web',
      domain: PUBLIC_BASE_URL,
    });
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
