# WYNOS Web Beta2 — suspended archive

> Status: **SUSPENDED / NO NEW DEVELOPMENT**
>
> Founder decision: 2026-09-29.

WYNOS Web Beta2 is no longer an active development track. The completed work from
this track was folded into **WYNOS Web Beta1** and released to eligible public users.

## Released into WYNOS Web Beta1

- WYN-159 — Threads-style chat, including reactions and delete-for-me.
- WYN-135 — Club chat edit, pin and search.
- WYN-137 — Club announcements.

The production database release migration is
`supabase/migrations_web_beta1_release_developer_features.sql`. It removes only
the developer-account rollout checks and preserves conversation membership, Club
membership/staff roles, moderation rules, RLS and RPC grants.

Club announcements remain **without automatic member notification fan-out** for
this release. The feature itself is public on Web; a future notification change
must be handled as a separate Web Beta1 task because other clients share the
notification schema.

## Development rule from 2026-09-29 onward

- Do **not** add new entries to `BETA2_RELEASED`.
- Do **not** create new Web Beta2 feature branches, release plans or staging flows.
- All new web work belongs to **WYNOS Web Beta1**.
- New user-facing Web Beta1 features are developer-first by default using the
  existing `is_developer_account()` / `useIsDeveloperAccount` staged rollout.
- Non-developers must continue seeing the existing behavior until the Founder
  explicitly releases that feature.
- Bug fixes, security fixes and hotfixes to already-public behavior continue to
  follow the exceptions in `.wyn/company/WORKFLOW.md`.

The legacy `web/lib/beta2.ts` file remains only as a compatibility wrapper for
existing call sites. All entries are public and it must not be used for new work.
