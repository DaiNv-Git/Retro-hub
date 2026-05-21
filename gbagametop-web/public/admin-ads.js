const form = document.querySelector('#adConfigForm');
const statusEl = document.querySelector('#status');
const tokenInput = document.querySelector('#adminToken');
const apiBase =
  window.location.protocol === 'file:' ? 'http://localhost:3000' : '';

const defaultConfig = {
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

const booleanFields = [
  'adsEnabled',
  'bannerEnabled',
  'inlineBannerEnabled',
  'interstitialEnabled',
  'rewardedEnabled',
  'appOpenEnabled',
  'actionInterstitialEnabled',
  'discoverActionInterstitialEnabled',
  'savedGamePlayInterstitialEnabled',
  'importedGamePlayInterstitialEnabled',
  'consoleActionInterstitialEnabled',
  'downloadCompleteInterstitialEnabled',
  'playExitInterstitialEnabled',
  'featuredPicksRewardedEnabled',
  'skinRewardedEnabled',
];

const numberFields = [
  'inlineBannerEvery',
  'downloadInterstitialCooldownSeconds',
  'playExitInterstitialCooldownSeconds',
  'actionInterstitialCooldownSeconds',
  'appOpenColdStartCooldownMinutes',
  'appOpenForegroundCooldownMinutes',
  'appOpenBackgroundThresholdSeconds',
  'appOpenLaunchThreshold',
  'featuredUnlockMinutes',
];

function setStatus(message, type = '') {
  statusEl.textContent = message;
  statusEl.className = `status ${type}`.trim();
}

function readToken() {
  return tokenInput.value.trim() || localStorage.getItem('adminToken') || '';
}

function applyConfig(config) {
  for (const field of booleanFields) {
    const input = form.elements[field];
    if (input) input.checked = config[field] !== false;
  }

  for (const field of numberFields) {
    const input = form.elements[field];
    if (input) input.value = config[field] ?? '';
  }
}

function collectConfig() {
  const config = {};
  for (const field of booleanFields) {
    config[field] = Boolean(form.elements[field]?.checked);
  }

  for (const field of numberFields) {
    config[field] = Number(form.elements[field]?.value || 0);
  }

  return config;
}

async function loadConfig() {
  setStatus('Loading ad config...');
  const response = await fetch(`${apiBase}/api/app/ad-config`, {
    cache: 'no-store',
  });
  const payload = await response.json();
  if (!payload.ok) throw new Error(payload.error || 'Cannot load config');
  applyConfig(payload.config);
  setStatus(`Loaded at ${new Date(payload.updatedAt).toLocaleString()}`);
}

async function saveConfig(event) {
  event.preventDefault();
  setStatus('Saving ad config...');

  const token = readToken();
  if (token) {
    localStorage.setItem('adminToken', token);
  }

  const response = await fetch(`${apiBase}/api/app/ad-config`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'X-Admin-Token': token } : {}),
    },
    body: JSON.stringify({ config: collectConfig() }),
  });
  const payload = await response.json();
  if (!payload.ok) throw new Error(payload.error || 'Cannot save config');
  applyConfig(payload.config);
  setStatus(`Saved at ${new Date(payload.updatedAt).toLocaleString()}`, 'ok');
}

form.addEventListener('submit', (event) => {
  saveConfig(event).catch((error) => setStatus(error.message, 'error'));
});

document.querySelector('#reloadConfig').addEventListener('click', () => {
  loadConfig().catch((error) => setStatus(error.message, 'error'));
});

tokenInput.value = localStorage.getItem('adminToken') || '';
applyConfig(defaultConfig);
loadConfig().catch((error) => {
  applyConfig(defaultConfig);
  setStatus(`${error.message}. Showing built-in defaults.`, 'error');
});
