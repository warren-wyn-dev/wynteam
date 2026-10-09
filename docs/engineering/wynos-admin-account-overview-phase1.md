# WYNOS Admin — Central Account Overview (Phase 1)

Status: **development branch / draft PR; not migrated, enabled, merged, or deployed**.

## Scope and architecture

- Reuse the EXISTING Supabase Auth `auth.users.id` as the shared WYNOS Account ID.
- The existing Admin `/users/[id]` page shows a **read-only** account-service evidence panel.
- Display four independent indicators: Social profile, Food order/address, Merchant identity/application/membership, and Maps saved-place/suggestion/photo.
- Registration through Social does not create Food, Merchant, or Maps records.
- The evidence indicators must NEVER be labeled as definitive sign-in, activation, approval, access, subscription, or SSO status.
- Merchant approval and user account access remain governed by existing policies.
- No account duplication, cross-domain session sharing, role changes, or write actions are in this phase.

## Changes

- `supabase/migrations_wynos_admin_account_snapshot_v1.sql`: read-only RPC using `auth.users` and existing application tables.
- `admin/lib/admin-account-services.ts`: server-side Supabase RPC client.
- `admin/components/admin/account-service-status.tsx`: four-service status panel with explicit evidence disclaimer.
- `admin/app/(admin)/users/[id]/page.tsx`: Admin-only, flag-gated integration.
- `admin/.env.local.example`: documents the off-by-default flag.

## Authorization and rollout

The `admin_wynos_account_snapshot(uuid)` function is `SECURITY DEFINER`, but:
- It explicitly enforces that `auth.uid()` has `profiles.platform_role = 'admin'`.
- It revokes `EXECUTE` from `PUBLIC` / `anon` and grants to `authenticated` only.
- It uses `set search_path = ''`, fully-qualified table names, and outputs only booleans, an account UUID and account creation time.
- The Admin UI calls it only for role `admin`; moderators and regular users do not get the panel.
- The panel is disabled unless `WYNOS_ACCOUNT_OVERVIEW_ENABLED=true` is configured for the **Admin server**.
- Admin must never use a service-role key in its browser bundle.

Rollout sequence:

1. Review SQL definition, authorization, indexes and representative test coverage on staging.
2. Apply the SQL to a correctly migrated *isolated staging database* and verify the function exists.
3. Deploy a staging/preview Admin instance with `WYNOS_ACCOUNT_OVERVIEW_ENABLED=true` (not Production).
4. Test the Admin user-detail panel for real admin accounts and verify moderator and unauthorized direct API requests fail.
5. Complete QA, security, change-control, rollback, and Founder Production approval gates before any Production migration/deployment or feature enablement.
6. Rollback plan: disable the feature flag; separately review and remove the RPC only when safe.

Do NOT enable the flag until the matching RPC is available in that environment; otherwise the Admin user-detail page can fail due to the missing function.

## Test matrix / acceptance criteria

| Scenario | Expected |
|---|---|
| Social-only signed-up account | Same `auth.users.id`, profile indicator may be true; other activity indicators false |
| Food buyer with order / saved address | Food indicator true, without creating new account |
| Pending or inactive merchant application/member | Merchant indicator true; **does not imply approved** |
| Maps saved place / suggestion / photo | Maps indicator true |
| User who only browsed Food or Maps | Indicator may be false; copy does not claim never used |
| Moderator visits a user detail | Existing moderator view unchanged, no account panel |
| User or anon calls RPC directly | Access rejected |
| Admin calls RPC after migration | Read-only snapshot returned, no membership or data created |
| Existing user moderation workflow | No regression |
| Feature flag unset | Existing Admin UI unchanged |

## Exclusions / phase 2

- Cross-domain SSO (OIDC/OAuth Authorization Code + PKCE).
- Accurate per-service activation events and signup/access classification.
- Central management of passwords, devices, MFA/passkeys, account deletion, cross-service bans.
- Global account directory covering users without profile rows.
- Live Production release.

Any authentication architecture change or Production release requires explicit Founder approval.
