# Deployment Log — Guest Browsing (WYN-072) disabled

**Date**: 2026-09-08
**Owner**: AI Deploy & DevOps
**Change**: `_guestBrowsingEnabled = false` in `AuthMethodScreen` — hides the "เข้าชม WYNOS ได้เลย" button. See `.wyn/company/DECISIONS.md`, 2026-09-08 ("Guest Browsing (WYN-072) หยุดชั่วคราว") for the Founder request and implementation detail.

## Pipeline

1. PR [#316](https://github.com/warren-wyn-dev/wynteam/pull/316) opened from `claude/close-function-jad2vw` against `main`.
2. CI (`ci.yml` run [#34202310271](https://github.com/warren-wyn-dev/wynteam/actions/runs/34202310271)): all jobs green, including `Flutter` (`flutter analyze` + `flutter test`, 1442 tests) — **SUCCESS**.
3. PR squash-merged into `main` — commit `32a7105`.
4. `deploy-web.yml` triggered manually (`workflow_dispatch`, ref `main`) — run [#108](https://github.com/warren-wyn-dev/wynteam/actions/runs/34202718788), head `32a7105` — **SUCCESS**.
5. `curl https://wynos.online/` — **HTTP 200**.

## Status

**Deployed, not yet Founder-verified.** Per `.wyn/company/WORKFLOW.md`'s Production Verification section, HTTP 200 only confirms the site is up, not that the button is actually gone on the live page. No `.wyn/tasks/` entry exists for this change (a single-flag hotfix, not staged through Product→Design→Code→QA) — nothing to move to `completed/`. Flagging here for Founder to confirm on `wynos.online` that "เข้าชม WYNOS ได้เลย" no longer shows on the sign-in screen.
