# android-compose

Native Android app for Motchill, implemented with Jetpack Compose.

This workspace starts as a single-module Android app with a clean internal package
layout so later phases can grow the data, feature, and playback layers without
rewriting the shell.

## Current status

- Phase 0: scaffold and architecture spec
- Phase 1: data foundation in progress
- Next: home screen, detail screen, player, and search/category

## Build APK

Use the PowerShell script at `scripts/build-and-upload-deploygate.ps1` to:

- build the debug APK
- copy it into `docs/`

Example:

```powershell
.\scripts\build-and-upload-deploygate.ps1
```
