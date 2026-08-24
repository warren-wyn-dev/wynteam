# Deployment Log — WYN-051 (WYN Admin User Management) + fast-follow fix

Release: code-integration push to the designated session branch (not `main`)
Date: 2026-08-24

## QA Status

**WYN-051: PASS** — see `.wyn/tasks/approved/WYN-051-admin-user-management.md`'s Independent QA section. No defects found in WYN-051's own scope; 14 new SQL checks plus 5 adversarial probes beyond the regression suite, all passing.

**Separate finding, fixed in its own commit**: while reviewing WYN-051, QA reconfirmed the exact same NULL-role-bypass class WYN-050 found also exists in the pre-existing `send_system_notification()` (WYN-043, already on `main`). Fixed as an isolated fast-follow (commit `bc3cee0`) immediately after WYN-051, kept out of WYN-051's own diff for a clean audit trail. Bug report: `.wyn/tasks/bugs/WYN-043-send-system-notification-null-role-bypass.md`. Red→green proven the same way as every other fix this project makes.

## Build Status

- `check_schema_ordering.py`: OK
- All 22 SQL regression scripts (`wyn_021` through `wyn_051`): **PASS**
- `next build`: clean, 0 errors/warnings
- `npm run lint`: **0 issues**

## Deployment Target

**`claude/phase-7-continuation-5s8by3` on GitHub only** — pushed via `git push`, not merged into `main`, no PR opened (same reasoning as every prior push this session).

## Changes

Two commits:
- `ab47369` — WYN-051 itself: `moderation_actions.report_id` nullable, `admin_apply_user_action()`/`admin_unban_user()` RPCs, `admin_user_moderation_history` view, `audit_log_event_type_check` extended, new SQL test, and the Next.js search/detail pages + Dialog/Textarea/Select/Badge components.
- `bc3cee0` — the isolated `send_system_notification()` NULL-role-bypass fix + its regression check + bug report.

## Deployment Result

**Pushed successfully.** Both WYN-051 and the separate fix are code-complete and QA-approved; not yet merged into `main`. `admin/` still has no live hosting target (same gap as WYN-049/050).

## Production Verification

Not applicable — same Readiness Gate as every prior task. The live-data paths (real search results, real action outcomes visible on a real account) are untestable without a real Supabase project, same limitation documented since WYN-049.

## Rollback Plan

- **Code**: nothing on `main` yet; `git revert` either commit individually on the session branch if needed (they're independent).
- **Database**: WYN-051 adds 2 functions + 1 view + 2 nullable/constraint changes (`moderation_actions.report_id`, `audit_log_event_type_check`) — no data migration involved since no live database exists. The fast-follow fix changes one line of one existing function.

## Next Steps

Same as WYN-049/050: awaiting an explicit request to open a PR/merge to `main`, and Founder action on hosting + a real Supabase project. Phase 7's next task per the roadmap is WYN-052 (Admin Content Moderation).
