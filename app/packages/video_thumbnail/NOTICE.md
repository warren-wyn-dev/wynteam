# Vendored copy of `video_thumbnail` 0.5.6

## Why this exists

`app/pubspec.yaml` needs `video_thumbnail` (used by
`lib/features/pop/presentation/create_pop_screen.dart` to generate a JPEG
thumbnail for Pop video clips). The upstream package on pub.dev
(`video_thumbnail: ^0.5.3`, resolves to `0.5.6`, the latest published
version as of 2026-08-17) ships an `android/build.gradle` that:

- calls the removed `jcenter()` repository method (Gradle 9 no longer
  exposes this method on `RepositoryHandler` at all -- not just deprecated,
  the method is gone), and
- applies the Android Gradle Plugin with the legacy
  `apply plugin: 'com.android.library'` syntax instead of a `plugins {}`
  block, which fails to configure correctly alongside AGP 9+.

This project pins AGP `9.1.0` (`app/android/settings.gradle.kts`). Building
`flutter build apk` fails with:

```
Could not find method jcenter() for arguments [] on repository container ...
'kotlin-android' plugin requires one of the Android Gradle plugins ...
```

There is no newer `video_thumbnail` release that fixes this (0.5.6 is
upstream's latest, published 2025-05-14, and still has this exact
`android/build.gradle`), so upgrading the dependency isn't an option.

## What changed here

Only `android/build.gradle` was modified. It was rewritten to use the same
modern, self-contained buildscript + `plugins {}` pattern already used
successfully by other Flutter plugins this project depends on (see
`video_player_android` 2.12.0 and `image_picker_android` 0.8.13+19 in
`pubspec.lock`): declare the plugin's own AGP classpath
(`com.android.tools.build:gradle:8.13.1`) from `google()`/`mavenCentral()`
(no `jcenter()`), then apply `com.android.library` via `plugins {}`.

Everything else -- the Dart API (`lib/video_thumbnail.dart`), the Android
native implementation (`VideoThumbnailPlugin.java`), and the iOS
implementation (`ios/`) -- is byte-for-byte identical to the upstream
`video_thumbnail` 0.5.6 package on pub.dev. `MethodChannel` name and method
signatures are unchanged, so this is a drop-in replacement with zero
required changes to app code.

## Why a vendored path package instead of a Gradle-level `subprojects {}` workaround

A root-level Gradle hack (e.g. injecting a substitute repository for every
subproject, or monkey-patching this one project's plugin application from
the root `build.gradle.kts`) was considered but rejected: it would be less
visible/auditable (buried in root build logic instead of next to the code
it fixes), harder to remove cleanly once this dependency is replaced or
upstream fixes the issue, and riskier to get right across Gradle's plugin
resolution phases. This vendored copy is scoped to exactly the one package
that needs it, changes exactly one file, and is trivial to delete (revert
`dependency_overrides` in `app/pubspec.yaml` and remove this directory) the
moment upstream publishes a fixed release.

## How to remove this workaround later

1. Check if pub.dev has a `video_thumbnail` release newer than 0.5.6 with a
   fixed `android/build.gradle` (or switch to an actively maintained
   alternative package).
2. Remove the `dependency_overrides: video_thumbnail:` entry in
   `app/pubspec.yaml`.
3. Delete this `app/packages/video_thumbnail/` directory.
4. Run `flutter pub get` and `flutter build apk --debug` to confirm.

## License

Upstream `video_thumbnail` is MIT licensed (see `LICENSE` in this
directory, copyright John Zhong and contributors). This vendored copy
preserves the original license and copyright notice as required by the MIT
license terms.
