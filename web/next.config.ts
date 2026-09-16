import type { NextConfig } from "next";

// Supabase Storage serves every drop/profile/club image from the project's
// own subdomain (<ref>.supabase.co) plus the wildcard *.supabase.co covers
// self-hosted/custom Supabase domains across environments without needing a
// hardcoded per-environment hostname list.
const supabaseHostname = (() => {
  try {
    return process.env.NEXT_PUBLIC_SUPABASE_URL ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname : null;
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
    remotePatterns: [
      ...(supabaseHostname ? [{ protocol: "https" as const, hostname: supabaseHostname }] : []),
      { protocol: "https" as const, hostname: "**.supabase.co" },
    ],
  },
};

export default nextConfig;
