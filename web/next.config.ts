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
    return { protocol: url.protocol.slice(0, -1) as "http" | "https", hostname: url.hostname };
  } catch {
    return null;
  }
})();

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // The dev-mode indicator badge is fixed-positioned and, in the narrow
  // mobile reference-phone viewport used by tests/browser/content-reference-flow.spec.ts,
  // sits directly over the compose toolbar and intercepts every click there
  // (see the "compose supports text, poll and image conditional modes" test).
  // Dev-only UI — never rendered in a production build — so this has no
  // effect on wynos.online.
  devIndicators: false,
  images: {
    remotePatterns: supabaseRemotePattern ? [supabaseRemotePattern] : [],
  },
};

export default nextConfig;
