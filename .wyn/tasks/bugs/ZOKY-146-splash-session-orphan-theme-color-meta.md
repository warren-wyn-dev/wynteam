# Bug Report — ZOKY-146

Status: bugs
Severity: LOW (visual, dark mode status-bar colour only; no crash, no data or security impact; not a release blocker)
Owner: AI Debug Engineer
Found by: AI QA & Security re-test 4 (ZOKY-145), branch `feat/zoky-web-app-design` @ 5e232d68, 2026-10-22

Bug:
This only happens in a browser session where the Food splash played. After the first in-app navigation inside Food
(for example Home → `/food/login`), React removes the nameless splash meta (`meta[data-fx-splash-theme]`) and leaves one
of the layout's own theme-color metas in `<head>` as an orphan. Head before the navigation:
`[NONAME #f93384 (splash), #ffffff@light, #000000@dark]`. Head after it, for the rest of the session on Food routes:
`[#000000@dark (orphan), #f93384@light, #f93384@dark]`. With the splash skipped, the head after the same navigation is
`[#f93384@light, #f93384@dark]`. As a result, in OS dark mode the status bar is `#000000` instead of `#f93384`.
Light mode is unchanged. The orphan is cleaned up when the user leaves the Food layout (for example a client navigation
to `/login` or `/`). There are 0 page errors, and the meta count stays at 3 or fewer.

Reproduction: on a local production build with a fake env and `colorScheme: dark`: open a new session, load `/food`,
and wait about 4.5 s. Tap "เข้าสู่ระบบ", then list `meta[name=theme-color]`. Script:
`probe145h.mjs` / `probe145b.mjs` (QA scratchpad).

Root Cause (QA lead): the splash meta is prepended before hydration, so React's head hydration seems to claim it in
place of the layout's first theme-color meta. On the next head update React removes the splash node and leaves its real
node unowned. This is also why `m.remove()` crashed (ZOKY-145).
Fix (suggested, needs CTO decision with ZOKY-142): keep the splash colour out of React-owned head positions, or
re-assert theme-color after the first navigation.
Files Changed: (to be filled)
Tests: fresh-session dark-mode `/food` → `/food/login` → theme-color list equals the splash-skipped list.
Regression Risk: low; it touches the iOS splash status-bar colour (ZOKY splash tests in `food-standalone-account.test.mjs`).
Handoff to QA: follow-up, can ship together with ZOKY-142.
