# Bug Report — WYN-075 (P0 — production regression from WYN-074)

Status: **completed** — deployed to production (2026-09-01)
Reported by: Founder, 2026-09-01 (screenshot on production, หน้าโปรไฟล์)
Severity: **P0** — every post image, on every screen (Home feed + Profile), fails to load entirely on production. Strictly worse than the WYN-074 bug it was meant to fix.

## Symptom
Founder screenshotted a broken-image icon in place of a post's photo on Profile. Follow-up confirmed via AskUserQuestion:
- **Every post with an image** shows the broken icon, not just one.
- Same failure on **Home feed too**, not just Profile.

## Root cause
The WYN-074 fix (PR #197, deployed as GitHub Actions run `33529251136`) switched `HomeDropCard`'s image from `Image.network` to `CachedNetworkImage` (`cached_network_image: ^3.4.1`) to fix a blank-flash-while-loading issue. On the actual deployed Flutter Web build, `CachedNetworkImage` fails to load every image (the `errorWidget` fallback fires 100% of the time), whereas the same URLs loaded fine under plain `Image.network` before.

Investigated but not fully root-caused (see below) before deciding to revert:
- Ruled out CORS: `curl` against Supabase Storage's public bucket (both `OPTIONS` preflight and a real `GET`, with an `Origin` header matching production) returns `access-control-allow-origin: *` on both — CORS is not blocking anything.
- Attempted to reproduce directly in a headless Chromium (Playwright, pre-installed in the sandbox) against the live production URL to capture the real browser console/network error — blocked by this sandbox's own outbound proxy failing to tunnel Chromium's connections to `web-neon-sigma-66.vercel.app` (confirmed via the proxy's own `__agentproxy/status` endpoint showing repeated `ws_closed_mid_exchange` relay failures to that exact host, unrelated to the app) — plain `curl` through the same proxy to the same URL succeeds, so this is a Chromium-through-proxy limitation of the sandbox, not a way to reach the real bug.
- Attempted to query the `drops` table directly (Supabase REST, anon key) to compare `image_url` values before/after — blocked: `drops` RLS requires an `authenticated` role, and creating even a throwaway anonymous session to read with was blocked by the sandbox's own auto-mode action classifier.
- Leading (unconfirmed) hypothesis: `cached_network_image`'s default Flutter-Web codepath (`ImageRenderMethodForWeb.HtmlImage`, via `dart:ui_web.createImageCodecFromUrl`) behaves differently under CanvasKit/Skwasm than Flutter's own `Image.network` did on this exact build — possibly needing `crossorigin="anonymous"` in a way that doesn't like Cloudflare's cached response headers, or a plugin-registration gap specific to `flutter build web` in this repo's CI. Not confirmed with a real browser trace — flagged for follow-up investigation with real device/browser access, not blindly re-attempted blind on production.

## Decision
Given 100% image-load failure across the whole app in production, right now, the priority is restoring a known-working state over continuing to debug the new package blind. Reverted `HomeDropCard` back to `Image.network`, but kept a real fix for the original WYN-074 symptom using Flutter's own built-in `loadingBuilder`/`errorBuilder` (no external package needed):
- `loadingBuilder`: shows a neutral placeholder (`colorScheme.surfaceContainerHighest`) while `frame == null` (still loading), instead of the previous blank white gap.
- `errorBuilder`: shows a broken-image icon on a genuine failure, instead of silently showing nothing.
- Removed `cached_network_image` (and its transitive deps: `cached_network_image_platform_interface`, `cached_network_image_web`, `flutter_cache_manager`, `octo_image`, `sqflite`*, `rxdart`, `synchronized`) from `pubspec.yaml` entirely — fully unused now.

This keeps the fix for the original blank-flash complaint (still using Flutter's native, proven-on-this-build APIs) while undoing only the part that broke production.

## Implementation (AI Coding, 2026-09-01)
- `home_drop_card.dart`: `Image.network(..., loadingBuilder: ..., errorBuilder: ...)` replacing `CachedNetworkImage`. Removed the now-unused `cached_network_image` import.
- `pubspec.yaml`/`pubspec.lock`: removed `cached_network_image` and let `flutter pub get` drop the 8 now-unused transitive deps.

## QA (2026-09-01) — PASS
- `flutter analyze`: 0 issues
- `flutter test`: 871/871 passing
- Confirmed via grep: no `cached_network_image` import/usage remains anywhere in `app/lib`
- Confirmed `pubspec.lock` no longer lists `cached_network_image` or its transitive deps

**Final Status: PASS**

Handoff: ส่งต่อ AI Deploy & DevOps — P0, deploy ทันทีที่ Founder ยืนยัน ไม่มี schema change

## Deploy (AI Deploy & DevOps, 2026-09-01) — SUCCESS

Founder อนุมัติ ("Deploy") — merge PR #200 → `main` (commit `50c034787c72187da153bbe529c1751d2424225c`) → trigger `deploy-web.yml` (run [`33531506545`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33531506545), completed/success) → verify production: ทุก endpoint HTTP 200, `main.dart.js` ขนาดลดจาก 4,145,796 → 4,088,406 bytes (เล็กลงตามที่ลบ package ออก) ยืนยัน build ใหม่จริง

รายละเอียดเต็ม: `.wyn/logs/deployments/2026-09-01-wyn-075-real-deploy.md`

## Follow-up (not done in this task)
If real image caching on Flutter Web is still wanted later, re-investigate `cached_network_image` (or an alternative) with real browser dev-tools access to see the actual console/network error first, rather than guessing again.
