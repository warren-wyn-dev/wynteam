import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

/** Isolated GP Sandbox deployment preflight. Never returns credentials. */
export function GET() {
  const qaProject = process.env.NEXT_PUBLIC_SUPABASE_URL ===
    "https://pcatuxtenluqzjzzwsvl.supabase.co";
  const publicKeyConfigured =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.startsWith("sb_publishable_") === true;
  const verified = qaProject && publicKeyConfigured;
  return NextResponse.json(
    {
      sandbox: verified,
      gp_mode: "simulation_only",
      gp_collection_enabled: false,
      admin_access: "authenticated_user_and_explicit_gp_allowlist_required",
    },
    { status: verified ? 200 : 503, headers: { "Cache-Control": "no-store" } },
  );
}
