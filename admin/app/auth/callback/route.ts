import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

// QA-only OAuth/OTP code exchange. No email or query-driven redirect is trusted.
export async function GET(req: NextRequest) {
  const origin = new URL(req.url).origin;
  const errorUrl = new URL("/login?status=verification_failed", origin);
  if (process.env.NEXT_PUBLIC_SUPABASE_URL !==
      "https://pcatuxtenluqzjzzwsvl.supabase.co") {
    return NextResponse.redirect(errorUrl);
  }
  const code = req.nextUrl.searchParams.get("code");
  if (!code || code.length > 2048) {
    return NextResponse.redirect(errorUrl);
  }
  const supabase = await createClient();
  const { data, error } = await supabase.auth.exchangeCodeForSession(code);
  if (error || !data.user || !data.user.email_confirmed_at) {
    return NextResponse.redirect(errorUrl);
  }
  // Identity proven, but never assign roles here. Explicit QA allowlist
  // remains mandatory and must be granted separately by service_role.
  return NextResponse.redirect(
    new URL("/login?status=awaiting_gp_authorization", origin),
  );
}
