# WYNOS Android v1.0.0 Beta 1 — Google Play readiness audit

**Audit date:** 2026-10-13  
**Scope:** Read-only verification and a publication plan; **no merge, release workflow execution, Google Play upload, website deployment or account configuration**.
**Source branch:** `fix/android-beta1-play-api36-20261013`, PR [#1157](https://github.com/warren-wyn-dev/wynteam/pull/1157) (open, draft, unmerged at audit time).

## Evidence and confidence

| Item | Current evidence | Status |
| --- | --- | --- |
| Native Android platform | `android/` is Kotlin + Jetpack Compose, not WebView/TWA/PWA | Present in source |
| Package & version | `applicationId=io.wyn.wyn`; `versionName=1.0.0-beta1`; `minSdk=26` | Confirmed in Gradle |
| Play target API | `compileSdk=36`, `targetSdk=36` | Confirmed in PR; satisfies Play API target requirement from 2026-08-31 |
| PR Android CI | [Run 38402240789](https://github.com/warren-wyn-dev/wynteam/actions/runs/38402240789): `assembleDebug testDebugUnitTest lintDebug bundleRelease` | PASS |
| PR main CI | [Run 38402240686](https://github.com/warren-wyn-dev/wynteam/actions/runs/38402240686) | PASS |
| Robolectric screenshot tests | `android/app/src/test/resources/robolectric.properties` pins simulated `sdk=35` to match Robolectric 4.14.1; app remains target 36 | Fixed; Android 16 device testing still needed |
| Signed uploadable release AAB | `.github/workflows/android-release.yml` exists, manual and **main-only**; needs signing/upload key and public SDK client configuration | NOT BUILT / NOT VERIFIED in this audit |
| Debug or unsigned CI bundle | CI ran `bundleRelease`; CI does **not** upload the AAB in its artifact list and has no upload signing key | Build verified; **not Play-uploadable** |
| Google Play Console status | No connected Play Console integration or authenticated console inspection during this audit | UNKNOWN |
| GitHub signing/configuration secrets | Names are defined in workflow; their presence and correctness not verified; values must never be read into reports | UNKNOWN |
| Real Android phone QA | No real-device evidence for this API 36 PR | NOT VERIFIED |

## Important blockers before any Play submission

### P0 — Release artifact and app operation

- [ ] Founder authorizes merge of reviewed, green PR #1157 to `main` **separately**. Release workflow is deliberately locked to `main`.
- [ ] Confirm owner has a verified Google Play developer account, app registration and package name `io.wyn.wyn` available in that account. Do not assume any app/track exists.
- [ ] Confirm setup for Play App Signing and a recoverable upload-key management strategy. `android-upload-key.yml` can create GitHub Secrets but has not been run or verified in this audit.
- [ ] Confirm **presence**, not values, of required protected release inputs: `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_STORE_PASSWORD`, `ANDROID_UPLOAD_KEY_ALIAS`, `ANDROID_UPLOAD_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY`.
- [ ] Configure Google OAuth Android client using package `io.wyn.wyn` and relevant signing SHA-1. Current `signInWithGoogle()` shows `google_not_ready`; Google sign-in **does not work yet**.
- [ ] With approval to create a signed artifact (not upload), run **Android release bundle** manually from `main`. Validate `app-release.aab` signature, package ID, target API, versionCode uniqueness/monotonicity, `mapping.txt` and upload expiry (artifact retention seven days). Do not publish.
- [ ] Check actual bundled native libraries / Android 16 device compatibility (including 16 KB page-size requirement where native libraries are present).

### P0 — Data safety, policy and account deletion

- [ ] Supply a **real, publicly reachable, reviewed Privacy Policy** linked inside app and Play Console. The `platform_documents` terms/privacy content is described as placeholder in `ANDROID_RELEASE.md` and is not acceptable as a final policy. A public legal page was **not confirmed reachable** by this audit.
- [ ] Provide an external **account-deletion-request web resource**, usable without reinstalling the app and identifying WYNOS; add its URL to Play Console. In-app account deletion already has UI, but the repository release runbook identifies a data-removal gap for user media still in Storage.
- [ ] Audit and remedy associated data deletion across Supabase database, Storage and external processors; document justified retention. Treat changes to data-deletion backend as a separate approval-required change, not part of this audit.
- [ ] Prepare truthful Data Safety declarations: account info, profile, posts/photos, messages, Firebase push token, third-party services, security and retention. Internal-test-only apps may be exempt from the Data Safety form, **not** apps progressing to closed or production.
- [ ] Google Play **Social category / child-safety**: publish CSAE prohibition standards at a public URL, identify a child-safety contact, operate CSAM response process and an in-app user-feedback/report path; verify Play Console declaration.
- [ ] Verify UGC Terms acceptance, content/user reporting and blocking, human moderation response workflow and appropriate protection of minors. The presence of UI/report routes alone does not demonstrate an effective operational process.
- [ ] Provide a functioning reviewer demo account plus login/invite code instructions in English, available without expiring credentials, via Play Console App Access (never in git).
- [ ] Complete the appropriate audience/age/content-rating, access, ads, data handling and policy forms with accurate declarations; keep draft until approval.

### P1 — Device QA, deep links and store assets

- [ ] Install a release-equivalent signed build on physical Android 16, Android 13+ and an older supported phone (minimum API 26). Test status/navigation bars, predictive Back, keyboards, keyboard overlays, dark/light themes, Thai/English, crashes, network errors and accessibility.
- [ ] Test the shared Supabase user account (signup, login, email confirmation, password reset, switch), posts/polls/images, profile, clubs, DMs, notifications and report/block flows.
- [ ] Verify Firebase messages on device (foreground, background and tap routing) and push-token handoff across account switches.
- [ ] Verify Play **app-signing** SHA-256 and digital asset links. The source route at `web/app/.well-known/assetlinks.json/route.ts` returns an empty list until valid fingerprints are configured; runtime URL could not be verified. A web production config/deploy must be separately approved.
- [ ] Prepare WYNOS app icon (source candidate `web/public/icons/icon-512.png`), store feature graphic 1024x500, at least two **real-app** phone screenshots, localized descriptions, contact details and privacy link. Do not use screenshots that misrepresent actual features.
- [ ] Test user reports and unresolved support/moderation tickets; validate operational response before broader testing.

## Rollout plan (future; **all stages separately approved**)

1. **Gate A — Technical QA:** resolve P0 runtime/security blockers; review PR #1157, run checks; get explicit authorization before merge.
2. **Gate B — Signed artifact only:** verify keys/config and then obtain explicit permission to run the manual `android-release.yml` on merged `main`; record public certificate fingerprints, AAB checksum, versionCode, and QA evidence. No Play upload.
3. **Gate C — Play Console draft:** owner creates/inspects app entry, checks identity, support URLs and disclosures; no track rollout yet.
4. **Gate D — Internal test:** after explicit approval, upload the verified signed AAB to the Play internal track (up to 100 testers); test on physical devices.
5. **Gate E — Closed test:** after approval, complete required setup and closed testing. **Personal Play accounts created after 2023-11-13** generally need at least **12 opted-in testers continuously for 14 days**, and then must apply for production access; verify exact account-specific status.
6. **Gate F — Production:** only after legal/security/device QA, policy review and separate explicit Founder approval.

## Official Google references (checked 2026-10-13)

- Target API: https://support.google.com/googleplay/android-developer/answer/11926878
- Personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Internal testing: https://support.google.com/googleplay/android-developer/answer/9845334
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Privacy Policy / User Data: https://support.google.com/googleplay/android-developer/answer/10144311
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- User-generated content: https://support.google.com/googleplay/android-developer/answer/9876937
- Child Safety Standards: https://support.google.com/googleplay/android-developer/answer/14747720
- Reviewer login access: https://support.google.com/googleplay/android-developer/answer/15748846
- Store assets: https://support.google.com/googleplay/android-developer/answer/9866151

**Audit conclusion:** Engineering build **PASS** is not Play submission **READY**. The signed AAB, real-device QA, account/Play configuration, legal documents, deletion correctness, reviewer credentials and social safety operations remain open. No release action has been performed.
