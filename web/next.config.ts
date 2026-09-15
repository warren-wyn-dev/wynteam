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
  images: {
    remotePatterns: [
      ...(supabaseHostname ? [{ protocol: "https" as const, hostname: supabaseHostname }] : []),
      { protocol: "https" as const, hostname: "**.supabase.co" },
    ],
  },
};

export default nextConfig;
