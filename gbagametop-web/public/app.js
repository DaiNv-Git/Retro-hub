const grid = document.querySelector('#gameGrid');
const statusEl = document.querySelector('#status');
const searchInput = document.querySelector('#searchInput');
const loadMoreButton = document.querySelector('#loadMoreButton');

let page = 1;
let totalPages = 1;
let search = '';
let isLoading = false;
let queuedReset = false;
let requestVersion = 0;
const pageSize = 24;

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function gameCard(game) {
  const title = escapeHtml(game.title);
  const region = escapeHtml(game.region || 'Unknown');
  const version = escapeHtml(game.version || '1.0');
  const platform = escapeHtml(game.platform || 'Game Boy Advance');
  const thumbnail = escapeHtml(game.thumbnail || '');
  const sourceUrl = escapeHtml(game.sourceUrl || '#');
  const downloadUrl = escapeHtml(game.downloadUrl || sourceUrl);
  const actionLabel = game.downloadUrl ? 'Download' : 'Open page';
  const downloadAttr = game.downloadUrl ? 'download' : '';

  return `
    <article class="game-card">
      <a class="cover" href="${sourceUrl}" target="_blank" rel="noreferrer">
        <img src="${thumbnail}" alt="${title}" loading="lazy" />
      </a>
      <div class="game-body">
        <h3 class="game-title">${title}</h3>
        <div class="meta">
          <span class="pill">${platform}</span>
          <span class="pill">${region}</span>
          <span class="pill">v${version}</span>
        </div>
        <div class="card-actions">
          <a class="button primary" href="${downloadUrl}" ${downloadAttr}>${actionLabel}</a>
        </div>
      </div>
    </article>
  `;
}

async function loadGames({ reset = false } = {}) {
  if (isLoading) {
    queuedReset = queuedReset || reset;
    if (reset) requestVersion += 1;
    return;
  }
  isLoading = true;
  const version = ++requestVersion;

  if (reset) {
    page = 1;
    grid.innerHTML = '';
  }

  statusEl.className = 'status';
  statusEl.textContent = 'Loading games...';
  loadMoreButton.disabled = true;

  try {
    const params = new URLSearchParams({
      page: String(page),
      pageSize: String(pageSize),
    });
    if (search) params.set('search', search);

    const response = await fetch(`/api/games?${params.toString()}`);
    const payload = await response.json();
    if (!payload.ok) throw new Error(payload.error || 'Cannot load games');
    if (version !== requestVersion) return;

    totalPages = payload.meta.totalPages;
    grid.insertAdjacentHTML('beforeend', payload.data.map(gameCard).join(''));
    statusEl.textContent = `${payload.meta.total.toLocaleString()} games found`;
    loadMoreButton.style.display = page < totalPages ? 'inline-flex' : 'none';
    loadMoreButton.disabled = false;
    page += 1;
  } catch (error) {
    statusEl.className = 'status error';
    statusEl.textContent = error.message;
  } finally {
    isLoading = false;
    if (queuedReset) {
      queuedReset = false;
      loadGames({ reset: true });
    }
  }
}

function debounce(fn, wait) {
  let timer;
  return (...args) => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => fn(...args), wait);
  };
}

searchInput.addEventListener(
  'input',
  debounce((event) => {
    search = event.target.value.trim();
    loadGames({ reset: true });
  }, 260),
);

loadMoreButton.addEventListener('click', () => loadGames());

loadGames();
