# Deployment Log — WYN-133 (Club Chat channel navigation + categories)

Date: 2026-09-07

## What deployed

- Schema: `public.club_channel_categories` table (RLS: any authenticated user reads, only that Club's owner/admin writes) + nullable `club_channels.category_id` (`on delete set null`) — via `.github/workflows/wyn133-apply-club-channel-categories-schema.yml` (`workflow_dispatch`), run [34140272931](https://github.com/warren-wyn-dev/wynteam/actions/runs/34140272931), **success**.
- Client: PR #308 (`feat(club): WYN-133 -- Club Chat channel navigation + categories`) + follow-up analyze-fix PRs #309/#310, all merged into `main` (head `df26ecc`). Deployed via `deploy-web.yml` (`workflow_dispatch`), run [34140342528](https://github.com/warren-wyn-dev/wynteam/actions/runs/34140342528), **success** (build + Vercel production deploy both green).

## What AI verified itself

- `supabase/tests/wyn_133_club_channel_categories_test.sh` — 7/7 RLS checks pass against a scratch Postgres loaded with the full `schema.sql`.
- `python3 supabase/check_schema_ordering.py` — OK.
- CI on `main` (run [34139400704](https://github.com/warren-wyn-dev/wynteam/actions/runs/34139400704)): `flutter analyze` (0 issues) + `flutter test` (full suite, including the rewritten `club_chat_tab_test.dart`) both green, plus Admin (Next.js) and Supabase Edge Functions.
- Apply-schema workflow's own diagnose/verify/smoke-test steps confirm the table + column exist on production and are queryable.
- Code-level adversarial review against every WYN-133 Acceptance Criterion (channel list on open, push-navigate on tap, back returns to list, unread dot live per-channel + re-syncs on return, category CRUD + move, "ลบห้องสุดท้ายไม่ได้" guard preserved, non-manager sees no manage UI, `isDeveloperAccount()` gate untouched, DM system files untouched).

## What AI could NOT verify itself

- No live hands-on run through the actual deployed app (no browser/device access in this session). Founder should sign in with a developer account, open a Club's "แชท" tab, and confirm: channel list appears, tapping a channel opens the full-screen room, back returns correctly, and (if wanted) try creating a category and moving a channel into it.

## Rollback

If something's wrong: the schema change is purely additive (new table + nullable column, nothing dropped or altered destructively) — no rollback needed on the DB side even if the client is rolled back. To roll back the client, re-run `deploy-web.yml` against the previous commit (`af55d5c`, PR #307's merge) via `workflow_dispatch`.

## Status

Deployed. Awaiting Founder's own hands-on confirmation in the app before moving this task from `.wyn/tasks/qa/` to `.wyn/tasks/completed/`, per `.wyn/company/WORKFLOW.md`'s Production Verification split (AI confirms CI/automated checks; Founder confirms real usage).
