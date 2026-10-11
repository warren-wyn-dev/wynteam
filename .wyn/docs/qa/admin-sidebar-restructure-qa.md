# QA — Admin Sidebar restructure (2026-10-11)

Branch: `feat/admin-sidebar-restructure` · Scope: `admin/` navigation only (no Auth, API, DB or RLS change)
Decision record: `.wyn/company/DECISIONS.md` → "[2026-10-11] Admin Sidebar"

## Route mapping (old → new section)

| Menu (old label) | New section › label | URL (unchanged) | Permission (unchanged) |
|---|---|---|---|
| Dashboard (ภาพรวม) | Dashboard รวม (top, no section) | `/` | any |
| User Management | Account › User Management | `/users` | account or social |
| Team Permissions (ระบบ) | Account › Roles & Permissions | `/team` | super admin |
| Content Moderation / Report Center / Announcements | Social | `/moderation`, `/reports`, `/announcements` | social |
| Orders | Food › Orders | `/food/orders` | food:edit |
| Stores (Food) | **Merchant** › Stores | `/food` | food |
| Merchant Applications | Merchant › Merchant Verification | `/merchants` | merchant |
| Coupons / Campaigns / Ads / Promo Notifications (Food) | **Merchant** | `/food/coupons`, `/food/campaigns`, `/food/ads`, `/food/notifications` | food (Ads: food:edit) |
| Places | Maps › Place Management | `/maps/places` | maps |
| Audit Log (ระบบ) | อื่นๆ › Audit Logs | `/audit-log` | super admin |
| — (new) | Dashboard of each system | `/dashboard/{account,social,food,merchant,maps}` | that system (checked server-side) |

Not built yet, shown disabled as "เร็วๆ นี้" (no link): Account Security, Customers, Payments & Refunds,
Customer Support, Menu Management, Map Reports, AI Secretary, Platform Marketing, System Settings.

## Results

| Check | Result |
|---|---|
| `npm run lint` | PASS |
| `npx next typegen && npx tsc --noEmit` (CI commands) | PASS |
| `npm run build` | PASS (all 23 routes) |
| Playwright E2E against `next start` + local mock Supabase (real proxy/layout auth + permission filtering) | **81/81 PASS** |

E2E coverage:
- Menu order matches the spec exactly; no duplicate links; every pre-existing page is still reachable.
- All 20 links clicked: URL, HTTP 200, `aria-current`, header title; deep links (`/food/orders/<id>`, `/food/stores/<id>`, `/users/<id>`, …) highlight the parent item; Back/Forward update the active item.
- Collapse/expand by mouse and keyboard (`aria-expanded`); navigating into a collapsed section re-opens it.
- Tablet 820px: permanent sidebar. Mobile 390px / 320px: drawer opens from header, closes by X, Escape (focus returns to menu button), tap outside and on selecting an item; no horizontal scroll; touch targets ≥ 44px.
- RBAC: super admin, `food:view` staff, `social:edit` staff, legacy moderator (pre-WYN-219) each see only the items they did before; direct URLs to dashboards they lack are refused server-side; `/food/orders` still refuses customer data to view-only staff; unknown `/dashboard/<x>` renders Not Found.

Known limitation of the test setup: the mock returns empty data, so the detail pages opened with a fake id
(`/food/orders/abc`, `/food/stores/abc`) error server-side — unrelated to the sidebar. Real numbers on the
new dashboards must be confirmed on preview/staging against the real database.

Bugs found and fixed during QA: header overflow of 9–36px on phones; focus not returning to the menu button after closing the drawer.

## Release gates

- No CRITICAL/HIGH findings. Navigation hiding is UI only; every page and RPC still re-checks access.
- Production deploy: **not done** — waits for explicit Founder approval (`deploy-admin.yml`, target `production`).
- Rollback: revert the merge commit and redeploy the previous Admin build; no data or schema to roll back.
