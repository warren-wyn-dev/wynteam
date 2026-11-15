# Switching place search to Norswor Maps (Zoky)

Founder decision 2026-11-15. The Norswor Maps geo API (`/api/geo/search`, `/reverse`, `/health`; see the Norswor-Maps repo, `docs/GEO_API.md`) answers place **names**, not street addresses. The customer still types the street address. Routing is **not** moved: it keeps going to the current upstream.

## Vercel environment changes on `zoky-web` (names only; the owner sets the values)
1. Preview first. Set `WYNOS_GEO_ORIGIN` to `https://<maps-host>/api/geo` and `WYNOS_MAPS_UPSTREAM_TOKEN` to the shared secret that Norswor Maps holds as `NMAP_GEO_TOKEN`. Keep `ZOKY_MAPS_UPSTREAM_ORIGIN` as it is.
2. With `WYNOS_GEO_ORIGIN` set (at build time), `next.config.ts` serves `/api/maps/search` and `/reverse` from this project and keeps forwarding only `/api/maps/route` upstream. Unset `WYNOS_GEO_ORIGIN` to go back to forwarding everything.
3. Compare 30 real Thai delivery queries between the old and new provider on preview before any production change. Production needs Founder approval.
4. Rollback: remove `WYNOS_GEO_ORIGIN` and redeploy (the build reads it).

Do not remove `ZOKY_MAPS_UPSTREAM_ORIGIN` yet: routing and the legacy fallback still depend on it. The legacy Maps stays up for 2 to 4 weeks after the production switch.
