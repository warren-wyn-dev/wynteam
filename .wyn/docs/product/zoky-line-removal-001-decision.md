# ZOKY-LINE-REMOVAL-001 — decision record

Date: 2026-11-12 · Decided by: Founder

## Decision
LINE is removed from ZOKY entirely (customer app, Merchant, store QR, notifications, backend).
Founder: nobody except the Founder ever used LINE, so existing link data may be removed.

## What changed
| Step | PR | Result |
|---|---|---|
| L1 | #1344 | LINE UI hidden; store QR is a plain web link; `/line` redirects to `/food`; `send-push-notification` stops sending LINE |
| L2 | #1345 | Remaining LINE web code and `@line/liff` removed |
| Deploy | #1346 | `--yes` for the CI Supabase deploy; `send-push-notification` deployed 2026-11-12 (run #33) |
| L3 | this change | `line-link` / `line-webhook` Edge Functions, `zoky-line-*` workflows and the LINE test removed from the repo; migration `20261112180000_zoky_drop_line_links.sql` drops `public.line_links` |

## Still to do outside the repo (not done by this change)
1. Apply the drop migration to production (destructive; Founder go-ahead at apply time).
2. Delete the deployed `line-link` and `line-webhook` functions in Supabase (Dashboard -> Edge Functions). Deleting the repo code does not remove them.
3. Remove Edge Function secrets for LINE (channel secrets/tokens, `LINE_NOTIFICATIONS_ENABLED`) in Supabase.
4. Remove `NEXT_PUBLIC_LIFF_ID_FOOD` / `NEXT_PUBLIC_LIFF_ID_MERCHANT` in Vercel (`zoky-web`, `web`).
5. Close the LINE OA / LIFF apps at LINE Developers.
6. Merchant Flutter: new build/release so the in-app text matches.

## Rollback
Revert the PRs. The table can be recreated from `20261031120000_zoky_line_links.sql`; deleted link rows are not restored.
