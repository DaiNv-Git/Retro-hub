# GBA Game Top Web

Standalone website and public API for `gbagametop.shop`.

## Run locally

```bash
npm start
```

Open `http://localhost:3000`.

## Environment variables

```bash
PORT=3000
PUBLIC_BASE_URL=https://gbagametop.shop
DATA_URL=https://engfordev.top/gbagame/data.json
APP_DATA_FILE=/var/www/gbagametop-web/data/legal-games.json
DISCORD_URL=https://discord.gg/vSh2kmcR
CACHE_TTL_MS=600000
```

## API

- `GET /api/health` - service status.
- `GET /api/discord` - returns the Discord invite JSON.
- `GET /api/discord?redirect=1` - redirects to Discord.
- `GET /api/home` - full public web payload from `DATA_URL`.
- `GET /api/games?page=1&pageSize=24&search=pokemon` - full public web games.
- `GET /api/games/:id` - public web game detail by id or slug.
- `GET /api/app/home` - legal app payload from `APP_DATA_FILE`.
- `GET /api/app/games` - legal app games.

Flutter app data is read from `data/legal-games.json`. Only add games you have
the right to distribute, such as official free demos, open-source homebrew, or
files where the developer/publisher permits public downloads.

## Deploy

Any Node 18+ host works. Point `gbagametop.shop` to the host and set:

```bash
PUBLIC_BASE_URL=https://gbagametop.shop
DISCORD_URL=https://discord.gg/vSh2kmcR
DATA_URL=https://engfordev.top/gbagame/data.json
APP_DATA_FILE=/var/www/gbagametop-web/data/legal-games.json
```
