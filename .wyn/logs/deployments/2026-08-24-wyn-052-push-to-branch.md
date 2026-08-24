# Deployment Log — WYN-052 (WYN Admin Content Moderation)

Release: code-integration push to the designated session branch (not `main`)
Date: 2026-08-24

## QA Status

**WYN-052: PASS** — see `.wyn/tasks/approved/WYN-052-admin-content-moderation.md`'s Independent QA section. Core fix (self-restore-defeats-moderation) verified closed for both the direct `admin_remove_drop()` path and the pre-existing Report-driven `apply_moderation_action()` path, with an executable regression test (23 checks, `wyn_052_admin_content_moderation_test.sh`) rather than just a read of the code.

**One pre-existing test needed updating, not a regression**: `wyn_029_moderation_queue_test.sh`'s `CHECK20` asserted the old hard-delete behavior for `remove_content` against a Drop -- that behavior is exactly what this task intentionally supersedes (Drop now soft-deletes so it can be restored). The assertion was rewritten to check `deleted_at is not null` + the row still existing, with a comment explaining why and pointing at the new suite for full restore-path coverage. Not a code change, a test-truth update.

## Build Status

- `check_schema_ordering.py`: OK
- All 24 SQL regression scripts (`wyn_021` through `wyn_052`): **PASS**
- `next build`: clean, 0 errors/warnings
- `npm run lint`: **0 issues**
- Verified no `service_role`/`SUPABASE_SERVICE` string reaches the client bundle (`.next/static`) -- still 0 service-role keys anywhere in `admin/`, same invariant as WYN-049/050/051
- Guest redirect verified against the 2 new routes (`/moderation`, `/moderation/[id]`) with a throwaway dev server + dummy (non-real) env vars, deleted immediately after -- both 307 to `/login`, same as every existing route

## Deployment Target

**`claude/pending-tasks-ogs3jb` on GitHub only** -- pushed via `git push`, not merged into `main`, no PR opened (same reasoning as every prior Phase 7 push this project has made: this session was not asked to open a PR).

## Changes

- `supabase/schema.sql`: `moderation_actions.target_content_type`/`target_content_id` (nullable, polymorphic) + 2 check constraints + index; `restore_drop()` redefined with the self-restore-defeats-moderation guard (the core fix); `apply_moderation_action()` redefined so Report-driven `remove_content` against a Drop now soft-deletes and records `target_content_type`/`target_content_id` instead of a hard DELETE (drop_comment/club_post/club_post_comment untouched); `audit_log_event_type_check` extended with 2 new event types; 4 new RPCs -- `admin_remove_drop()`, `admin_restore_drop()`, `admin_search_drops()`, `admin_get_drop()`; `admin_user_moderation_history` VIEW extended with the 2 new columns (appended at the end -- Postgres rejects inserting view columns mid-list via `create or replace view`).
- `supabase/tests/wyn_052_admin_content_moderation_test.sh`: new, 23 checks.
- `supabase/tests/wyn_029_moderation_queue_test.sh`: `CHECK20` rewritten to match the intentionally-changed soft-delete behavior.
- `admin/lib/admin-moderation.ts`, `admin/lib/admin-moderation-actions.ts`: new data layer.
- `admin/app/(admin)/moderation/page.tsx` (replaces the WYN-049 placeholder), `search-form.tsx`, `results.tsx`, `app/(admin)/moderation/[id]/page.tsx`: Screens 1/2 per the Design spec.
- `admin/components/admin/drop-moderation-actions.tsx`: new, single Remove-or-Restore action bar.
- `admin/components/admin/action-dialog.tsx`: extended `triggerVariant` to accept `"destructive"` (was `"outline"|"default"` only) and wired the confirm button to the same variant, needed for the Design spec's Remove/Restore styling -- verified this doesn't change any of WYN-051's 4 existing dialogs (all still pass `"outline"`, confirm button still renders `"default"` exactly as before).

## Deployment Result

**Pushed successfully.** WYN-052 is code-complete and QA-approved; not yet merged into `main`. `admin/` still has no live hosting target (same gap as WYN-049/050/051).

## Production Verification

Not applicable -- same Readiness Gate as every prior task. Live-data paths (real search results against a real Supabase project, a real restore reaching a real client) are untestable without a real Supabase project, same limitation documented since WYN-049.

## Rollback Plan

- **Code**: nothing on `main` yet; `git revert` the commit(s) on the session branch if needed.
- **Database**: no live database exists, so no data migration/rollback is involved. If this were live: `restore_drop()`/`apply_moderation_action()` would need reverting to their pre-WYN-052 definitions first (to stop new soft-deletes/restore-blocking), and any Drop rows soft-deleted under the new behavior would need a one-time hard-delete pass to match the old externally-visible effect, since the DDL itself (`target_content_type`/`target_content_id` columns) is additive and safe to leave in place either way.

## Next Steps

Same as WYN-049/050/051: awaiting an explicit request to open a PR/merge to `main`, and Founder action on hosting + a real Supabase project. Phase 7's next task per the roadmap is WYN-053 (per the sidebar placeholders already scaffolded in WYN-049 -- Reports/Audit Log/Announcements still placeholder).
