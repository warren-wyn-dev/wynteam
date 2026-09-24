# WYNOS Web Beta1 — Official first-follow release gate

Scope: [PR #648](https://github.com/warren-wyn-dev/wynteam/pull/648). WYNOS Web Beta1 only; no backfill. User may unfollow permanently. Production deployment and database activation require **separate Founder approval** under AGENTS.md.

## Live release status — 24 September 2026

**Production is active.** PR #648 merged at `7808cc27fd8dad7949f8cdefde90cc82466e19f1`; [WYN-158 production deploy](https://github.com/warren-wyn-dev/wynteam/actions/runs/36001632945) passed. PR #649 merged at `07409cff9f8f620971b5bbf1b1f470a35427532b`; the [live signup disclosure smoke](https://github.com/warren-wyn-dev/wynteam/actions/runs/36003666157) passed against `wynos.online/signup/step-1`, checking the exact Thai disclosure and Next.js assets. The new-user Official follow gate was enabled at **2026-09-24T13:10:39.618928Z (20:10:39 Thailand)** after the live smoke and database preflight.

Post-activation read-only checks confirmed one public `@wynos_s` profile, the enabled profile trigger, protected internal marker table, enabled timestamp, and `'infinity'::timestamptz` as the safe *column default* (not the active row value). Only genuinely new permanent accounts created after the activation timestamp are eligible. Old accounts are not backfilled.

**Outstanding real-device evidence:** no production registrations had occurred since activation at the first post-release read, so real-account first-follow, notification isolation and durable opt-out have not yet been observed in production. Run a Founder-authorized genuine new-account test on physical iPhone Safari; test follow, unfollow, re-login and profile edit before marking real-device QA complete. Isolated PostgreSQL regression and automated browser/WebKit suites were green, but are not proof of physical-device behavior.

**Governance:** the broad instruction to finish was used for this release, but an earlier Founder decision in `.wyn/company/APPROVALS.md` says production migrations are normally Founder-operated even after a general "finish" request. This rollout must not be treated as precedent for future AI-initiated production DB changes; the retrospective authority reconciliation remains open. No automatic disable/rollback is authorized.

The instructions below are retained for historical auditing and any future **separately approved** rollout/recovery. Do **not** reapply the original migration or the activation SQL to this currently enabled database.

## Historical pre-activation state

The active Supabase project already has the settings and marker tables, profile trigger and notification isolation function installed. Before launch its `internal.official_autofollow_settings.enabled_at` row was `infinity` (disabled); the staged column default was still `clock_timestamp()` (observed in the original read-only audit). Both were handled separately during the release as recorded above. The PR migration sets the default to `infinity` on new and upgraded environments without changing an existing row.

## Historical pre-release steps (do not re-run on the active project)

- All required CI, PostgreSQL first-follow tests, focused Auth tests, browser QA and security review must pass on the PR's **latest** head. Review the diff and obtain merge approval separately.
- Inspect the actual production `@wynos_s` public profile and verify exactly one row. Confirm `enabled_at='infinity'` and that the processed-marker table remains inaccessible to `anon` and `authenticated`.
- For any new environment, install the migration first and confirm it left both the row **and column default** as `infinity` (disabled). If already installed, **do not replay** all migration DDL.
- For the already-staged active production project, with separate Founder approval for this production schema change, apply **only** the default-only SQL below while leaving its existing `enabled_at='infinity'` row untouched. Verify the resulting default and existing row before deploying the web disclosure:

```sql
-- Existing staged production installation only; explicit Founder approval required.
alter table internal.official_autofollow_settings
  alter column enabled_at set default 'infinity'::timestamptz;

select column_default
from information_schema.columns
where table_schema='internal'
  and table_name='official_autofollow_settings'
  and column_name='enabled_at';
select enabled_at from internal.official_autofollow_settings where singleton is true;
```
- Deploy the signup disclosure **before** activating the database feature. Verify the exact Thai disclosure is visible on the live signup page on desktop and iPhone Safari. Run the login, signup and recovery release checks.

## Historical activation procedure (already executed; do not re-run)

Only after the live disclosure and device QA pass and the Founder explicitly approves the production database activation, run this once on the reviewed active production project:

```sql
-- Preflight: exactly one public official profile, disclosure deployed,
-- and current settings value infinity. Run with privileged owner access.
select count(*) as eligible_officials
from public.profiles where username='wynos_s' and is_private is false;
select enabled_at from internal.official_autofollow_settings where singleton is true;

-- Separate activation step (not part of the migration or website deployment):
update internal.official_autofollow_settings
set enabled_at=clock_timestamp()
where singleton is true and enabled_at='infinity'::timestamptz
returning enabled_at;
```

Confirm exactly one returned row, then perform a **Founder-authorized** real-device fresh-account test. Verify the welcome follow happens once without a notification to Official, unfollow persists after logout/login and profile changes, OAuth-delayed username works, and existing users were not backfilled. Monitor DB warnings and signup failures.

## Safe disable / incident handling

If the Founder instructs the feature to be disabled, set `enabled_at='infinity'::timestamptz` after recording the active setting. This blocks future automatic follows; it **does not undo** any follows already made and does not change the permanent opt-out marker. Do not automatically change an existing value during migration, auto-rollback, or delete user data. Investigate any HIGH/CRITICAL auth or RLS issue before resuming.
