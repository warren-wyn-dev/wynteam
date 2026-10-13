# WYNOS Android v1.0.0 Beta 1 — Connected Backend QA APK

Date: **2026-10-13**  
Status: **Workflow prepared on Draft PR #1157; environment configuration, manual build and device verification pending.**  
Founder instruction: prepare a Beta 1 Android APK connected to the same Supabase backend as `wynos.online`; **no merge, production web deployment, Play Console upload or publication**.

## What changed and why

The already installed Debug APK shows "ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับแอปนี้" because PR CI intentionally builds without `WYNOS_SUPABASE_URL` and `WYNOS_SUPABASE_PUBLISHABLE_KEY`.

- `android/app/build.gradle.kts` already supports the build-time environment variables.
- `SupabaseProvider` reuses the approved Supabase Auth/PostgREST/Realtime/Storage backend and server-side RLS; no new app login system, database migration or backend key required.
- The GitHub `Android` workflow now has an additional **connected-qa** job, only when **manually dispatched on branch `fix/android-beta1-play-api36-20261013`**.
- The existing unconfigured PR CI stays unchanged and does **not** receive Supabase client settings. `connected-qa` requires the `android` build/test job to pass before building its QA artifact.
- `connected-qa` uses the `android-qa` GitHub Environment, which **the Founder must create and protect** prior to any manual run. Its build environment receives **only the publishable client URL/key**. It refuses missing values and non-anon JWT keys. No service role, JWT secret, personal account password, Firebase server key, payment key or cloud admin key belongs here.
- The successful artifact is `wynos-android-beta1-connected-qa-apk` (ZIP containing `app-debug.apk`, retained 3 days). It is **not a release AAB** and is not uploaded to Play.

### Security note

The Supabase **publishable/anon** client key, by design, will be embedded inside the resulting Android APK and is therefore **not secret**, even though GitHub Secrets/Environment Secrets are used to control the build pipeline. Treat the artifact as potentially public to repository collaborators. Access control **must** be enforced by the existing Supabase RLS and auth permissions. This is a **real backend**; actions from a signed-in tester can affect real data. Only test with authorized dedicated test accounts, use minimal synthetic content, and do not run destructive or spammy operations. This is not a backend E2E or RLS penetration test.

## Exact Founder setup steps in GitHub (do not send values in chat)

1. Open https://github.com/warren-wyn-dev/wynteam/settings/environments
2. Create environment **`android-qa`**. In its Deployment protection rules, configure **Required reviewers** (ensure an eligible reviewer can approve) and **Deployment branches and tags → Selected branches/tags** with exactly `fix/android-beta1-play-api36-20261013`. Confirm these protections were actually saved. Never manually trigger connected QA before this is complete.
3. In this environment, create exactly two **Environment secrets** (their values are not returned to the assistant):
   - `SUPABASE_URL` — the **HTTPS Project URL** for the same Supabase project currently used by WYNOS Web. Supabase Dashboard → Project Settings / Data API (location may vary).
   - `SUPABASE_PUBLISHABLE_KEY` — the project's **publishable client key** (`sb_publishable_...`) or legacy `anon` key; obtain from Supabase Dashboard → API Keys. **Never use `service_role`, `sb_secret_`, database password or a user's login password.**
4. Do **not** set Firebase credentials yet. This QA APK intentionally tests only Supabase login and social functionality. Google sign-in is currently a documented not-ready stub.
5. After environment/secrets are ready, go to https://github.com/warren-wyn-dev/wynteam/actions/workflows/android.yml and choose **Run workflow** → branch `fix/android-beta1-play-api36-20261013` → **Run workflow**. This manual dispatch runs the regular `android` build/test first; only after it passes and the environment reviewer approves will `connected-qa` run. If `connected-qa` is skipped, check that the run was triggered **manually from that exact branch**, not through PR.
6. Open the successful Actions run → **Artifacts** → **`wynos-android-beta1-connected-qa-apk`**. Download ZIP on the Android phone, extract it, and install `app-debug.apk` from Android Files. The ordinary artifact `wynos-android-beta1-debug-apk` is *still unconfigured*—do not confuse them.
7. Debug signing keys on different runners may not match. An install update can fail with a signature conflict; **before removing any existing app, back up required local data**. Only uninstall the previous debug package after verifying its contents are disposable. Never uninstall a real Play-installed app just to test a debug APK.
8. Android QA: app loads without the red not-configured message; login **using a dedicated test account**; verify correct profile, home feed, post/media, comments, chat, clubs, settings and logout. Do not post real credentials or account data in screenshots. Report device model, Android version, observed result and any error text with sensitive fields redacted.

## What is NOT finished yet

- [ ] `android-qa` protected GitHub Environment created and reviewer/branch protection verified by the Founder
- [ ] Correct **public** Supabase URL and publishable/anon key inserted in `android-qa` secrets
- [ ] Manual connected-qa workflow run successful and artifact exists
- [ ] APK installed and backend login verified by real-device QA
- [ ] Firebase Android client / push notifications configured and tested
- [ ] Google sign-in Android OAuth registration and implementation completed
- [ ] Signed Play AAB prepared and tested (requires separate approval)
- [ ] Legal/privacy/UGC/deletion checks and Play Console listing finished

## Branch / release containment

- Draft PR: https://github.com/warren-wyn-dev/wynteam/pull/1157
- QA workflow path: `.github/workflows/android.yml` (already has `workflow_dispatch` on the default branch, so selected-branch manual dispatch is available)
- Production WYNOS Web remains unchanged.
- No database schema edits, secret values, backend writes or Play releases are involved in this setup.
- Rollback of this scoped workflow change is a normal PR revert; **never** roll back production or merge without Founder instructions.
