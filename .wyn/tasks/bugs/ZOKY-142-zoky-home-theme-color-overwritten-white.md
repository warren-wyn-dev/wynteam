# Bug Report — ZOKY-142

Status: bugs
Severity: LOW (visual; pre-existing on `release/zoky-web-20261018` @ 0533fb36, not introduced by cc823142)
Owner: AI Debug Engineer
Found by: AI QA & Security, branch `feat/zoky-web-app-design` @ cc823142, 2026-10-19

Bug:
Spec 4.1 says the Home `theme-color` is `#F93384` (pink status bar, white text). The server HTML has `#f93384`
(`web/app/food/layout.tsx`), but once a signed-in session loads, `applyChromeColor` in `web/lib/theme-preference.ts`
(via ThemeSync) rewrites every `meta[name=theme-color]` to `#ffffff` / `#000000`. The new Food page sets `#FFEFF5`
correctly and then restores the white value on leaving, so on Android Chrome / installed PWA the Home status bar is
white above the pink header.

Reproduction: local production build, mocked session; open `/food` and read
`meta[name=theme-color]` contents after load → `#ffffff,#000000` (same on base build 0533fb36 and on cc823142).

Root Cause: the theme preference sync does not know about the Food origin's brand theme-color.
Fix (suggested): skip/keep the Food brand color inside the Food app (e.g. mark the Food metas like the splash meta, or
let ThemeSync leave `/food` alone). Needs CTO decision because it touches the shared theme code.
Files Changed: (to be filled)
Tests: theme-color stays `#f93384` on Home, `#FFEFF5` on Food, restored to `#f93384` after leaving Food.
Regression Risk: low; Social pages must keep their white/black colors.
Handoff to QA: follow-up; not a release blocker for this redesign.
