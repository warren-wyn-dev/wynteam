# WYNOS Admin

Web-based admin panel for WYN (Phase 7 of the V1.0.0 roadmap, `.wyn/docs/product/wyn-v1.0.0-roadmap.md`) — completely separate from the Consumer app (`app/`) per Master Spec section 36 ("WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง"). Entry is checked server-side using the shared profile and WYN-219 system permissions; individual pages and operations enforce their required system/level.

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
- `app/(admin)/` — protected dashboards, user management, moderation, reports, announcements, Food, Merchant, Maps and team permissions. `layout.tsx` uses the request-scoped identity and access from `requireAdminRole()` (`lib/auth.ts`); each page and RPC checks its required permission. Menu entries without implemented pages remain disabled with a "เร็วๆ นี้" badge.
- `lib/supabase/` — `client.ts` (browser), `server.ts` (Server Components/Actions), `middleware.ts` (session refresh, used by `proxy.ts`)
- `components/ui/` — hand-written shadcn/ui primitives (Button/Input/Label/Card) — the `shadcn` CLI's `init`/`add` commands reach `ui.shadcn.com`, which this project's sandbox network policy blocks; `components.json` is still configured correctly if a future session has network access to use the CLI normally
- `components/admin/` — sidebar/header/placeholder-page, specific to this app's layout

## Scripts

- `npm run dev` — dev server
- `npm run build` — production build (also runs the TypeScript check)
- `npm run lint` — ESLint
- `npm test` — synthetic navigation, authentication/session and dashboard-read regression tests; no production credentials or database required

## Navigation and reliability

- The sidebar and mobile drawer search permitted menus by Thai aliases, English labels and category names, without making additional network requests. Clearing search restores the expanded/collapsed categories.
- Logout shows pending and retry states. If Supabase clears the browser session while global revocation fails, login explains that the browser is signed out and other devices could not be confirmed. Session redirects preserve cookie removals and Supabase SSR cache protection.
- Failed login retains the entered email so retrying needs only a new password.
- Dashboard read RPCs use a 10-second request timeout and retain the existing partial-error notices. This bounds stalled reads; it does not establish production latency or load capacity.
- Announcement/reminder audit histories show their super-admin restriction to other staff instead of claiming no messages have ever been sent.

## Data access

Admin uses the signed-in user's session and permission-checked database RPCs. No service-role key is used in this app. Navigation visibility is not an authorization boundary.


## Production deployment

WYNOS Admin is deployed as its own Vercel project from the `admin/` root, using the same Supabase project as the rest of WYNOS. Production deployment remains manual after the initial project bootstrap.

The current coordinated release freeze and outstanding acceptance criteria are in [`WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`](../docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md). Passing these local regressions does not establish that every planned system is complete or deployed.
