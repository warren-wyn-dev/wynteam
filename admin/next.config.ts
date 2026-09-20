import type { NextConfig } from "next";

// /_next/image is excluded from proxy.ts's auth matcher (Next.js requires
// the optimizer route itself stay reachable), so remotePatterns is the only
// gate on what this server will fetch on a caller's behalf. A wildcard
// hostname here would turn it into an open image proxy for any Supabase
// tenant, not just this project's -- scope it to exactly the configured
// project, and derive the protocol from that same URL instead of hardcoding
// https (self-hosted/local Supabase, e.g. `supabase start`, serves over
// plain http).
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
  images: {
    remotePatterns: supabaseRemotePattern ? [supabaseRemotePattern] : [],
  },
};

export default nextConfig;
