# WYNOS Android Beta 1 — compact native UI QA

Scope: Kotlin/Jetpack Compose only on `fix/android-beta1-play-api36-20261013`. No changes to Web, backend, environment, Play publishing or release signing.

## Design direction
- Native visual scale is consistent across feed, profile, authentication, club, post composer, chat, search, settings, notifications, quote and follow screens.
- Common body text targets 15sp/20sp line height; primary tabs 14sp; primary app bar 17sp; headings remain meaningfully larger.
- Compose Material3 uses a shared type scale. **Never override LocalDensity.fontScale**; respect Android accessibility font and display settings.
- Home tabs support two lines at large system font sizes so Thai `กำลังติดตาม` remains legible on narrow screens.
- Keep the Thai `ดูเพิ่มเติม` action as a single line, separate from the tag tokens; tag spans remain clickable.
- Profile avatar target 88dp; bottom nav icons 24dp; keep bottom nav interactive area 49dp, home tabs 48dp, quick-compose 58dp.
- Maintain 48dp or larger effective touch targets wherever practical; check touchable bounds manually. Icon visual size is not tap target size.
- Do not modify media grid layout, profile content order, actual data, links, account/session behavior, or accessibility semantics.

## QA gates before calling this ready
1. GitHub Android CI passes `assembleDebug testDebugUnitTest lintDebug bundleRelease` (including Robolectric screenshots).
2. Manual connected QA build runs on protected `android-qa` branch only, no secrets in logs or screenshots.
3. On Pixel 5 Android 12 test all five main tabs, profile edit, feed, hashtags, see-more, media, create-post, quote, chat, notifications, club create, searches, menu and account settings.
4. Verify default device font/display settings and also larger font size (about 130–150%), narrow width, Thai/English, dark/light, keyboard open, landscape if available.
5. Verify long Thai/English labels do not clip or overlap; app respects cutouts, navigation and status bars; first touch never blocked.
6. Check authentication, logout/login, session persistence, network retry, saved/unsaved post actions, RLS-driven state before production QA sign-off.
7. Record any screen-specific regressions and repair on the Android PR branch. **CI green alone is not device QA success**.
8. Do not merge PR, upload signed AAB or release through Google Play without Founder approval.

## Relevant examples
- `feature/home/HomeScreen.kt`: HomeTabs and QuickCompose
- `feature/home/PostCard.kt`: caption + see more
- `feature/profile/ProfileScreen.kt`: hero/avatar/profile body
- `feature/shell/MainShell.kt`: bottom navigation
- `core/design/Theme.kt`: Material type scale
