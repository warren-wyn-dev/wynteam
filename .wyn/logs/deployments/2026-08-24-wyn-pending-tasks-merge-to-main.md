# Deployment Log — Pending Tasks branch (email+password sign-in, guest-bypass removal, BETA label, WYN-046 fix) merged to `main`

```
Release: claude/pending-tasks-ogs3jb -- email + password sign-in (any email, unlimited accounts), removal of the guest-mode bypass now that real sign-in paths exist, a BETA label on the Welcome screen, a WYN-046 document-acceptance fix for brand-new users, and a Home feed header/scroll fix (already independently re-derived and shipped to main earlier the same session via the mobile-ui-design branch -- this merge reconciles the two).
Version: N/A (no versioned build yet -- code-integration merge only, see Readiness Gate below)
QA Status: PASS
  - flutter analyze: clean, both merge rounds (this branch had fallen behind main by ~7 hours of concurrent work -- WYN-056/057/058, WYN-062, WYN-063, the first real production deploy, and two P0 web-auth fixes -- so it was merged forward twice, in two rounds, resolving conflicts by hand each time; see Changes below).
  - flutter test: 762/762 pass (final count) -- 759 baseline (post WYN-062/063) + this branch's own new tests (email_auth_screen_test.dart, WYN-046 platform-documents regression, home_feed_screen_test.dart updates), no regressions from either merge round.
Build Status:
  - flutter analyze (Flutter 3.47.1 stable, already installed in this sandbox from earlier in the session): 0 issues.
  - flutter test: 762/762 pass.
  - Native flutter build apk/ipa / flutter build web: NOT attempted from this session -- see Readiness Gate below for why the web build+deploy step specifically could not be completed here.
Deployment Target: `main` branch on GitHub (warren-wyn-dev/wynteam) only -- a code-integration step. See Readiness Gate below for why the actual Vercel production redeploy could not be performed from this session.
Changes:
  - Merge round 1 (conflicts in `auth_repository.dart`, `home_feed_screen.dart`): kept `main`'s already-live, Founder-tested fix for the P0 Google/Apple-Sign-In-broken-on-Web bug (`_mobileOauthRedirect` + `kIsWeb` check) over this branch's own independent, never-shipped attempt at the same fix; kept `main`'s WYN-063 Home Feed Algorithm sliver wiring (`onHide`, `_hideItem`) intact while re-adding this branch's own `onHide` support on top of the current (post-header-fix) `_buildBodySlivers()` structure.
  - Merge round 2 (conflicts in `auth_method_screen.dart`, `widget_test.dart`): this branch had independently decided to remove the Apple and Phone/OTP buttons entirely (11:26 UTC, before this branch's work concluded); `main` independently fixed Apple's OAuth redirect (16:05 UTC) and hid Phone behind a reversible `_phoneLoginEnabled` flag rather than deleting it (16:14 UTC) -- both strictly after this branch's decision, and directly informed by the Founder testing the actually-deployed production site. Resolved by keeping `main`'s more recent, production-validated decision (Google + Apple visible, Phone hidden-not-deleted) and layering this branch's own additive Email+password button on top -- nothing from either branch's real work was silently dropped.
  - No schema/RLS changes in this batch.
Deployment Result: PR #165 merged to `main` cleanly after both merge rounds (merge commit `1b61a56`). `origin/main` verified at `1b61a56` after fetch.
Production Verification: NOT PERFORMED from this session -- see Readiness Gate.
Readiness Gate (partial -- differs from every prior log's blanket "no infra" finding, because real infra now exists and a prior session in this same project already completed one real production deploy today):
  - A real Supabase project, Google OAuth, and a Vercel production site (https://web-neon-sigma-66.vercel.app) all already exist and were already used for a real deploy earlier today by a concurrent session (see `.wyn/logs/deployments/2026-08-24-wyn-056-057-058-real-deploy.md`).
  - **This session's own outbound network policy blocks both `api.vercel.com` and `*.supabase.co`** -- confirmed directly (`curl` to both returns `CONNECT tunnel failed, response 403` from this sandbox's egress proxy, i.e. an organization policy denial, not a Vercel/Supabase-side error). Per this proxy's own operating instructions, a 403 policy denial must be reported, not retried or routed around. This session could therefore merge the code but could not run `flutter build web` + `vercel deploy --prod` (or even a read-only Supabase connectivity check) itself.
  - The concurrent session that performed today's earlier real deploy evidently had a different/wider egress policy and was able to reach both hosts.
Rollback Plan:
  - Code: `git revert` merge commit `1b61a56` on `main` restores the pre-merge state.
  - Database: no changes in this batch -- nothing to roll back.
  - Distribution: not applicable to this entry -- no new build was produced or deployed by this session.
```

## Next Steps

1. **A production redeploy is still needed** to actually ship this batch's changes (email+password sign-in, the BETA label, the WYN-046 fix) to https://web-neon-sigma-66.vercel.app -- the code is merged and ready, but no session with the right egress access has rebuilt+redeployed since this merge landed. Either: (a) widen this session's egress policy to allow `api.vercel.com`/`*.supabase.co` and it can be done from here, or (b) the concurrent session (or Founder, or a session with matching network access) runs `flutter create . --platforms web && flutter build web --release --dart-define-from-file=dart_define.json && vercel deploy --prod` from a repo checked out at `main`'s current tip.
2. **Credential rotation reminder (repeated from the earlier log, now doubly relevant)**: the same Supabase PAT / DB password / Vercel deploy token / Google OAuth secret were pasted in plaintext chat a second time this session, to a different Claude session than the one that used them first. Consider rotating all four once today's deploys are confirmed working, per the recommendation already recorded in `.wyn/logs/deployments/2026-08-24-wyn-056-057-058-real-deploy.md`.
3. Native mobile (iOS/Android) build/distribution remains blocked on `google-services.json`/`GoogleService-Info.plist`, a distribution channel, and either a CI pipeline or an Android SDK/Xcode-equipped environment -- unchanged from every prior deployment log.
