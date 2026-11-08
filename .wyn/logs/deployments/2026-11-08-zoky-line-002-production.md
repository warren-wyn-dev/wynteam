# Deployment record — ZOKY-LINE-002 (login guidance + LIFF redirect skip) — 2026-11-08

- Approved by Founder (explicit, in session): release commit `53f9e494` (items 1+2), build without domain switch, then separate approval to promote.
- Source: branch `claude/zoky-line-002-release-candidate` = production baseline `a70cbb03` + (1) LINE login guidance on /food/login (2) next.config redirect skips LIFF browser. App code identical to `53f9e494` (workflow-only diff verified by the build job).
- Build: GitHub run 42448696128 (`zoky-line-002-production-build.yml`), `vercel deploy --prod --skip-domain --force`, Vercel deployment `dpl_7B62FanBFc9pmqqzH2sK4xcDZuVa` (READY).
- Promote: `request_promote` → all 9 production domains now alias `dpl_7B62…` (verified via list aliases); previous deployment `dpl_Aoc6Vet9q4XDEXRC3SUywHEwjFWe` has no aliases.
- Rollback: Vercel Instant Rollback / promote `dpl_Aoc6Vet9q4XDEXRC3SUywHEwjFWe` (no migration involved).
- Post-release smoke (read-only fetch): zoky `/`, `/food/login`, food `/line`, merchant, wynos.online, geo health → 200; zoky brand intact. maps.wynos.online → 307 to wynos.online/maps (not compared with pre-release behaviour).
- NOT verified: real LIFF/LINE user agents on iOS/Android (redirect skip and guidance box rely on SDK-derived regex), Playwright WebKit specs, staging for item 2.
- Follow-ups: remove deployment-branch rules `claude/great-cori-5zsvjp`, `claude/zoky-line-002-login-guidance-prod`, `claude/zoky-line-002-release-candidate` from the GitHub `production` environment; capture real LIFF `navigator.userAgent`; baseline usability test.
