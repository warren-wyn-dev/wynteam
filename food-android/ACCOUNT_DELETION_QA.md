# WYNOS Food Android — shared account data rights (staging preview)

## Why this is sensitive

WYNOS Food uses the **shared WYNOS Account**. Calling the existing
`public.delete_my_account()` RPC deletes that user from the WYNOS identity
system and affects WYNOS Social, Merchant and other linked services.
It is **not** limited to the Food app, and cannot be undone.

The existing WYNOS website and Flutter app already use this RPC. No new
database tables, migrations or deletion endpoints are introduced here.

## Native UX

- A discoverable native account-deletion entry in Account.
- Large warnings that all WYNOS services are affected.
- Exact typed confirmation in Thai/English and a **second** confirmation
  dialog before any RPC can run.
- A session-owner-only RPC with **no user ID parameter**; all identity
  checks occur on the server.
- After a successful RPC, clear the local Supabase session and cached
  orders, addresses, cart, quote and account state.
- Errors stay visible and do not silently claim deletion succeeded.

## Strict staging guard

Account deletion is **always disabled in release and in normal debug APKs**.
It can be enabled only for an authorized disposable QA account in debug
when all four values are present:

```text
WYNOS_FOOD_SUPABASE_URL=https://<staging-project-ref>.supabase.co
WYNOS_FOOD_STAGING_PROJECT_REF=<same-staging-project-ref>
WYNOS_FOOD_SUPABASE_PUBLISHABLE_KEY=<staging-publishable-key>
WYNOS_FOOD_ACCOUNT_DELETION_STAGING=true
```

The exact URL/ref must match, the ref must be 20 lower-case alphanumeric
characters, and production ref `kqokpocajhfbidcxpvhh` is excluded.
These values are not set in the CI builds.

## Release blockers and QA

1. Obtain an approved, isolated staging project with seeded disposable users.
2. Test server auth/RPC permission and ownership with a disposable QA user;
   no production account deletion is permitted during QA.
3. Verify post-deletion auth state after app restart, offline/timeout failure,
   duplicate taps, failed RPC, and remote-signout rejection.
4. Review retention of Food orders/invoices and data protection obligations
   when deleting a shared WYNOS Account.
5. Prepare a publicly accessible account-deletion request URL for the Play
   Console Data Safety form and confirm that it works unauthenticated.
6. Before Play release, separately approve enabling account deletion in
   the release build and complete destructive-action regression E2E.
7. Do not merge/deploy/publish without final release approval.

This feature is a **test implementation, not evidence of Play compliance**.
