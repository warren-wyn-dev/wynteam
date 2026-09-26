import type { NextConfig } from "next";

// /_next/image is a public, unauthenticated route on wynos.online, and
// remotePatterns is the only gate on what it will fetch on a caller's
// behalf -- a wildcard hostname here would turn it into an open image proxy
// for any Supabase tenant, not just this project's, so scope it to exactly
// the configured project. Protocol is derived from that same URL rather
// than hardcoded https (self-hosted/local Supabase, e.g. `supabase start`,
// serves over plain http).
const supabaseRemotePattern = (() => {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL) return null;
  try {
    const url = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    // port must be explicit -- an omitted `port` field means "any port" to
    // Next's matcher, not "no port": with dangerouslyAllowLocalIP on for
    // dev, that would let /_next/image reach any other local service on
    // 127.0.0.1, not just the one at this URL's port.
    return { protocol: url.protocol.slice(0, -1) as "http" | "https", hostname: url.hostname, port: url.port };
  } catch {
    return null;
  }
})();

// WEB-B1-QA-01: baseline response hardening for every route. Clickjacking:
// no third-party page may frame a signed-in WYNOS session (one-tap follow,
// like, repost, accept message request). A full script CSP is a separate,
// larger change (Firebase, Supabase, Vercel analytics origins).
const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Content-Security-Policy", value: "frame-ancestors 'none'" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
  // The dev-mode indicator badge is fixed-positioned and, in the narrow
  // mobile reference-phone viewport used by tests/browser/content-reference-flow.spec.ts,
  // sits directly over the compose toolbar and intercepts every click there
  // (see the "compose supports text, poll and image conditional modes" test).
  // Dev-only UI — never rendered in a production build — so this has no
  // effect on wynos.online.
  devIndicators: false,
  images: {
    remotePatterns: supabaseRemotePattern ? [supabaseRemotePattern] : [],
    // remotePatterns alone doesn't cover it: Next.js's image optimizer also
    // unconditionally rejects any hostname that resolves to a private/loopback
    // IP (see is-private-ip.js), which is exactly what local Supabase CLI
    // (`supabase start`) binds to by default -- so local dev against it would
    // still 400 without this. Gated on NODE_ENV, which next build/Vercel
    // always set to "production" and which isn't settable via .env, so
    // wynos.online keeps full SSRF protection unconditionally; only `next dev`
    // gets the local-IP allowance. Founder-approved 2026-09-20 (see
    // .wyn/company/APPROVALS.md) since this is a security-policy change.
    dangerouslyAllowLocalIP: process.env.NODE_ENV !== "production",
  },
};

export default nextConfig;
