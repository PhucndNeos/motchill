# Release Artifacts

This folder stores release outputs for the current Motchill mobile app handoff.

## Current APKs

- File: [`motchill-arm64-v8a-release.apk`](./motchill-arm64-v8a-release.apk)
- File: [`motchill-armeabi-v7a-release.apk`](./motchill-armeabi-v7a-release.apk)
- File: [`motchill-x86_64-release.apk`](./motchill-x86_64-release.apk)
- Built from: `mobile-api-base`
- Build command: `cd mobile-api-base && flutter build apk --release --split-per-abi`

## Runtime Support

- The Android build uses Flutter's default `minSdk` of API 24, so it supports Android 7.0 and newer.
- The APK was built with the Android SDK Platform 35 installed on the build machine, but that only affects compilation, not the minimum Android version required on user devices.

## Notes

- Use the arm64-v8a build for most modern Android devices.
- Use the armeabi-v7a build for older 32-bit devices.
- Use the x86_64 build for Android emulators or x86_64 devices.
- If you build a new APK later, replace the matching ABI file or add a dated variant alongside it.
