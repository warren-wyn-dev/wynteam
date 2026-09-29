# WYNOS Consumer Web (Next.js migration)

This directory is the production WYNOS Web App (Next.js). The active web product/version track is WYNOS Web Beta1.

## Principles

- Preserve the WYNOS product/UX while changing the browser frontend implementation.
- Reuse the existing Supabase project, Auth, RLS and RPC contracts.
- Never put a service-role key in browser code.
- Use native browser DOM/CSS and `<img>` rendering instead of Flutter platform views/CanvasKit for migrated surfaces.
- Use browser/OS system fonts only. No SF Pro or other Apple font files are bundled or redistributed.
- New user-facing Web Beta1 features use developer-account staged rollout by default and open to everyone only after explicit Founder approval.

## System fonts

`app/globals.css` uses:

```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
  "Noto Sans Thai", "Helvetica Neue", Arial, sans-serif;
```

The browser chooses an installed font for the current OS. WYNOS does not ship Apple font files.

## Environment

Copy `.env.example` to `.env.local` and provide only the public Supabase URL and publishable key. The current backend RLS remains the security boundary.

## Commands

```bash
npm install
npm run dev
npm run check
```

## Migration status

- Phase 1: Next.js/React foundation, developer gate, system-font DOM rendering.
- Phase 2: interactive Home feed, comments, follows, repost/save/like and Create Drop.
- Phase 3: Search/Discovery, Profile, Notifications, Chat, Settings and supported deep-link routes.

The Next.js consumer web is live in production. Future Web Beta1 features are developed developer-first, then released publicly after QA and Founder approval. The Web Beta2 development track was suspended on 2026-09-29.
