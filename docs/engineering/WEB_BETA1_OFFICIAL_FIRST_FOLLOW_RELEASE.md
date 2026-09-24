# WYNOS Web Beta1 — Official first-follow release gate

Scope: [PR #648](https://github.com/warren-wyn-dev/wynteam/pull/648). WYNOS Web Beta1 only; no backfill. User may unfollow permanently. Production deployment and database activation require **separate Founder approval** under AGENTS.md.

## Current production fact

The active Supabase project already has the settings and marker tables, profile trigger and notification isolation function installed. Its `internal.official_autofollow_settings.enabled_at` row is `infinity` (disabled); do **not** run the migration a second time just to activate it. The original staged column default is still `clock_timestamp()` (observed in the live read-only audit). The PR migration sets the default to `infinity` on new and upgraded environments without changing an existing row.

## Before release (no production writes)

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

## Founder-approved, separate activation

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
