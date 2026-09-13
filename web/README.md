# WYNOS Consumer Web (Next.js migration)

This directory is the staged consumer-web replacement track for Flutter Web. It is not the production cutover by itself.

## Principles

- Preserve the WYNOS product/UX while changing the browser frontend implementation.
- Reuse the existing Supabase project, Auth, RLS and RPC contracts.
- Never put a service-role key in browser code.
- Use native browser DOM/CSS and `<img>` rendering instead of Flutter platform views/CanvasKit for migrated surfaces.
- Use browser/OS system fonts only. No SF Pro or other Apple font files are bundled or redistributed.
- Keep the migration developer-only until explicit Founder approval for public rollout.

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

## Phase 1

The first slice is a read-only developer-gated Home feed using the existing `is_developer_account()` and `get_wynos_ranked_feed()` RPCs. Write interactions and additional routes are migrated in later slices after parity tests.
