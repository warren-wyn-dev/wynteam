import type { NextConfig } from "next";

// Same pattern as web/next.config.ts: Supabase Storage serves every drop
// image from the project's own subdomain (<ref>.supabase.co), and the
// wildcard *.supabase.co covers self-hosted/custom domains across
// environments without a hardcoded per-environment hostname list.
const supabaseHostname = (() => {
  try {
    return process.env.NEXT_PUBLIC_SUPABASE_URL ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname : null;
  } catch {
    return null;
  }
})();

const nextConfig: NextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      ...(supabaseHostname ? [{ protocol: "https" as const, hostname: supabaseHostname }] : []),
      { protocol: "https" as const, hostname: "**.supabase.co" },
    ],
  },
};

export default nextConfig;
