# WYN Admin

Web-based admin panel for WYN (Phase 7 of the V1.0.0 roadmap, `.wyn/docs/product/wyn-v1.0.0-roadmap.md`) — completely separate from the Consumer app (`app/`) per Master Spec section 36 ("WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง"). Only accounts with `platform_role` set to `admin` or `moderator` (on the same shared `profiles` table) can sign in.

Stack (approved by the Founder as a Major Architecture decision, `.wyn/company/DECISIONS.md` 2026-08-24): **Next.js (App Router) + TypeScript + Tailwind CSS + shadcn/ui**, connected to the same Supabase project as `app/` via `@supabase/ssr`, deployed on Vercel.

See `.wyn/tasks/approved/WYN-049-admin-foundation.md` and `.wyn/docs/design/wyn-049-admin-foundation.md` for the full Product/Design spec this scaffold implements.

## Getting Started

```bash
npm install
cp .env.local.example .env.local   # fill in NEXT_PUBLIC_SUPABASE_URL / _PUBLISHABLE_KEY
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Unauthenticated requests to any route redirect to `/login`.

## Project Structure

- `app/login/` — sign-in page + Server Action (`actions.ts`) that verifies `platform_role` server-side before granting access
- `app/(admin)/` — every page behind the auth gate; `layout.tsx` calls `requireAdminRole()` (`lib/auth.ts`) before rendering any child page. Only `page.tsx` (Dashboard) has an owner right now (WYN-050); the other 5 routes (`users/`, `moderation/`, `reports/`, `audit-log/`, `announcements/`) are placeholders until WYN-051 through WYN-055 land
- `lib/supabase/` — `client.ts` (browser), `server.ts` (Server Components/Actions), `middleware.ts` (session refresh, used by `proxy.ts`)
- `components/ui/` — hand-written shadcn/ui primitives (Button/Input/Label/Card) — the `shadcn` CLI's `init`/`add` commands reach `ui.shadcn.com`, which this project's sandbox network policy blocks; `components.json` is still configured correctly if a future session has network access to use the CLI normally
- `components/admin/` — sidebar/header/placeholder-page, specific to this app's layout

## Scripts

- `npm run dev` — dev server
- `npm run build` — production build (also runs the TypeScript check)
- `npm run lint` — ESLint

## No service-role key yet

This foundation scope (auth + layout only) never needs to read another user's data, so there is no service-role client anywhere in this app — `profiles`' own RLS policy already lets a signed-in user read their own `platform_role`. The first task that needs to see across users (WYN-051 User Management, most likely) will need to introduce one carefully, server-only (see the Product spec's Risks section on why that key matters).
