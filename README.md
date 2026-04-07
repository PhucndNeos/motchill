# Motchill MVP

## Start Here

For the current player and stream-resolution investigation, read:

- [`HANDOFF_PLAYER_DEBUG.md`](./HANDOFF_PLAYER_DEBUG.md)

That file contains:
- the current backend/mobile architecture
- the stream URL resolution flow for mobile
- verified good/bad source behavior
- the latest debugging findings
- the next follow-up items for source resolution and player stability

## Repository Layout

- `backend/`: Fastify middleware that crawls public Motchill data, normalizes it, caches it, and resolves playback URLs.
- `mobile/`: Flutter app for Android/iOS that consumes the backend API and plays native-playable streams with `video_player`.

## Local Development

Backend:

```bash
cd backend
npm install
npm start
```

Flutter app:

```bash
cd mobile
flutter pub get
flutter run
```

Default API base URLs:

- Android emulator: `http://10.0.2.2:3000`
- iOS simulator: `http://127.0.0.1:3000`

Override with:

```bash
flutter run --dart-define=MOTCHILL_API_BASE_URL=http://your-backend:3000
```

## Key Endpoints

- `GET /health`
- `GET /api/home`
- `GET /api/search?q=...`
- `GET /api/episode/:slug`
- `GET /api/playback/:slug`
