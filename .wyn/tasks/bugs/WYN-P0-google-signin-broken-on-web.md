# Bug Report — WYN-P0 (Google/Apple Sign-In broken on the live Web production deploy)

Status: fixed
Owner: AI Debug Engineer (orchestrator, urgent/same-session fix — Founder reported "มันพังแล้ว ซ่อมด่วน" with a screenshot moments after the first real production deploy went live)

Bug: Tapping "เข้าสู่ระบบด้วย Google" (or Apple) on https://web-neon-sigma-66.vercel.app immediately shows Safari's "Safari ไม่สามารถเปิดหน้าเว็บได้เนื่องจากที่อยู่ของหน้าเว็บไม่ถูกต้อง" ("Safari cannot open the page because the web address is invalid") — the OAuth flow never reaches Google's consent screen at all. Phone-OTP sign-in and Anonymous sign-in (used in-app elsewhere) were unaffected, since neither goes through `signInWithOAuth`.

Reproduction: Open https://web-neon-sigma-66.vercel.app in Safari (iOS) or any browser → tap "เข้าสู่ระบบด้วย Google" → error dialog appears immediately, no navigation to accounts.google.com ever happens. Confirmed by reading Founder's screenshot directly (browser automation in this sandbox couldn't reproduce it live — this session's egress proxy resets Chromium's HTTPS traffic, a tooling limitation documented in the deployment log, not a proxy issue on the real production side).

Root Cause: `AuthRepository.signInWithGoogle()`/`signInWithApple()` (`app/lib/features/auth/data/auth_repository.dart`) hardcoded `redirectTo: 'io.wyn.app://login-callback'` unconditionally, on every platform. That custom URL scheme is registered for the **native** (iOS/Android) app only — on Flutter Web, Safari/Chrome have no handler for a non-http(s) scheme, so passing it as the OAuth redirect breaks the flow before it can even open Google's consent screen. This code was written back in WYN-002 when only native platforms existed ("Must be registered ... once the platform folders exist" -- the doc comment literally anticipated native-only, web wasn't built yet at the time) and was never revisited when Flutter Web support was added for today's first real deploy.

Fix: Made the redirect platform-aware using `kIsWeb`:
```dart
redirectTo: kIsWeb ? null : _mobileOauthRedirect,
```
`redirectTo: null` on web makes supabase_flutter fall back to the current page's own origin as the OAuth callback, which is already in the Supabase project's `uri_allow_list` (`https://web-neon-sigma-66.vercel.app`, `https://web-neon-sigma-66.vercel.app/**` — confirmed via the Supabase Management API, already configured before this session touched anything). Native (`io.wyn.app://login-callback`) is unchanged.

Files Changed: `app/lib/features/auth/data/auth_repository.dart` (both `signInWithGoogle`/`signInWithApple`, plus updated doc comments explaining the platform split).

Tests: `flutter analyze` clean. `flutter test` full suite: 725/725 pass (no existing test exercised `signInWithOAuth` directly — it triggers a real browser redirect, not something a widget test can drive — so this fix has no direct automated regression test; verifying it live in a real browser is the only way, which is exactly why the daily Vercel deploy quota being exhausted, below, is the actual blocker right now, not test coverage). Root-cause reasoning matches Supabase's own documented web-OAuth pattern (redirectTo omitted defaults to the current origin), and the failure mode (custom URI scheme rejected by the browser) is exactly what browsers do with unregistered non-http(s) schemes — high confidence without needing a live re-test, but a live re-test is still the real bar for closing this out.

Regression Risk: Low. Native sign-in path (`kIsWeb == false`) is byte-for-byte unchanged. Web path only affects the value of one optional parameter that was never correctly usable on web before this fix (i.e., web Google/Apple sign-in was 100% broken beforehand — there is no working prior web behavior to regress).

**BLOCKED ON DEPLOY, NOT ON CODE**: The fix is committed, tested, and merge-ready, but redeploying to the live URL hit Vercel's Hobby-plan **100-deployments/day** cap (`"Resource is limited - try again in 24 hours (more than 100, code: api-deployments-free-per-day)"`) — this repo's Vercel GitHub integration auto-deploys a preview on every push across every active branch, which appears to have consumed the day's quota well before this fix was ready. This is a Founder-facing infrastructure decision (upgrade the Vercel plan, or disable auto-preview-deploys for non-`main` branches to stop burning quota on routine WIP pushes) — see `.wyn/company/DECISIONS.md`.

Handoff to QA: once a deploy succeeds, re-verify live: tap "เข้าสู่ระบบด้วย Google" on the actual production URL in a real browser and confirm it reaches Google's consent screen (this session cannot do that verification itself — see Reproduction above).
