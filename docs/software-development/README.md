# Motchill Software Development Docs

These docs describe the current native Android app in `android-compose` and the shared API/domain model it uses.

## Subdocs

- [Architecture](architecture.md)
- [Modules and Screens](modules.md)
- [API, Data, and Storage](api-data.md)
- [Supabase Auth and Sync Flow](supabase-auth-sync.md)
- [Payload Decryption and Key Recovery](security-decryption.md)
- [Navigation Flow](navigation.md)

## Current Product Scope

- Browse home, search, categories, detail pages, and related items.
- Play episode sources in the native Android player.
- Keep playback position locally per episode.
- Support both direct stream sources and embedded `iframe` sources.

## Player Notes

- Native playback uses `androidx.media3` / ExoPlayer.
- `isFrame=true` sources are treated as embedded sources and are not part of the native playable rail.
- `Tracks.kind=captions` is treated as subtitle metadata, not as audio dubbing.
- If the backend returns a real audio dub, it must appear as an audio track or a separate playable source.
