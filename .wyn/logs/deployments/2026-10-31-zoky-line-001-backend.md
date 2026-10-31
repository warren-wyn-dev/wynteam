# ZOKY-LINE-001 backend production rollout — 2026-10-31

## Authorization

Founder approved D1–D6 ("อนุญาต"), then instructed "จัดการให้เสร็จ พร้อมใช้งานจริงเลย" and approved all three GitHub Production environment reviews. Record: `.wyn/company/APPROVALS.md` (ZOKY-LINE-001).

## What changed in production

| Step | Run | Result |
|---|---|---|
| PR #1304 merged to `main` (`5b29e05`) | all GitHub Actions CI green (Vercel Git statuses red on every PR: no GitHub account connected to Vercel) | merged |
| `zoky-line-apply.yml` — additive `public.line_links` | [41214649344](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214649344) | success; verified table_ready, rls_on, policies=2, anon_read=false, members_insert=false, members_update=false, members_read_line_id=false, members_delete=true |
| Deploy `line-link` | [41214748754](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214748754) | deployed to `kqokpocajhfbidcxpvhh` |
| Deploy `line-webhook` | [41214751671](https://github.com/warren-wyn-dev/wynteam/actions/runs/41214751671) | deployed to `kqokpocajhfbidcxpvhh` |

Post-deploy public smoke (no credentials, no data written): unsigned webhook → 401; unknown `?oa` → 404; `line-link` without JWT → 401; CORS preflight from `https://food.wynos.online` → 204 with that origin only.

## Deliberately not deployed

- `send-push-notification`: `main` also carries two reviewed but never-deployed push changes since the live 2026-10-05 deploy (`741c6717`): Merchant order details as push title, and no Social push to legacy `app = NULL` tokens. Deploying from `main` would ship them with LINE. Held for a Founder decision (deploy from `main`, or a LINE-only build on the live source). Not needed until LINE secrets exist.
- Web (`/line`, Food menu entry, Merchant card): needs `NEXT_PUBLIC_LIFF_ID_*` at build time and a scoped release on the live bases (Food/ZOKY `93e6954`, Merchant `ddc1fc2`; pending Merchant release `94c8d62`).

## Current state

LINE delivery is off: `LINE_NOTIFICATIONS_ENABLED` and LINE secrets are not set; `line-link` answers 503 `line_disabled` to signed-in callers. No customer-visible change.

## Rollback

Functions are inert without secrets. Table rollback (destructive, Founder approval): `supabase/rollbacks/20261031120000_zoky_line_links_rollback.sql`.
