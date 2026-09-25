# WYNOS Web Beta 1 — Phase 3 developer-gated release plan

Phase 3 retains existing published Post/Quote and Poll functionality. The incremental scope is private Bookmark Collections and a non-billing WYNOS Plus interface preview. **No subscription prices, benefits, entitlements or payment processor have been approved.** Do not infer or implement them from a visual preview.

## Bookmark Collections

Staged migration: `supabase/migrations_wyn191_bookmark_collections.sql`; matching clean-install `supabase/schema.sql`; role tests: `supabase/tests/wyn_191_bookmark_collections_test.sh`. Backend RLS requires authenticated ownership and an existing save for each Drop/Quote; unsaving removes the collection membership; quoted content is keyed by Quote ID rather than underlying Drop ID. A caller cannot read or mutate another user's collection, and `anon` has no grants.

**Launch order:** exact-head DB role QA and peer security review → Founder migration approval → apply migration to staging → verify account A/B, unsave cleanup, empty/large collections, lost/deleted posts, and rollback plan → apply approved production migration → enable `NEXT_PUBLIC_WYNOS_BOOKMARK_COLLECTIONS=1` in a newly built Preview → physical iOS/Android QA → separately authorized rollout. The flag is off by default, so existing Bookmarks remain unchanged before the migration.

## WYNOS Plus

`NEXT_PUBLIC_WYNOS_PLUS_PREVIEW=1` exposes an informational membership preview in Settings. The default is off. **No checkout, pricing, paid entitlements, fake subscription status or automatic billing**. Payment provider, prices, feature tiers, refunds, receipts, country eligibility and launch require separate Founder product and legal decisions; the UI explicitly says membership is not open.

## Required QA

`npm run test:phase3-collections`, `npm run check`, full Supabase maintained RLS suite, and mobile/desktop Playwright with feature flags and staging schema. Confirm saved Quote IDs, collection pagination, name validation/duplicates, blocked/deleted content and A→B isolation. Preserve existing Bookmark action placement at the right side of posts and existing Feed media grid.
