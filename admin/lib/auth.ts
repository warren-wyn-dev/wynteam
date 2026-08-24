import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type AdminRole = "admin" | "moderator";

/**
 * Resolves the signed-in user's platform_role and enforces the
 * admin/moderator gate server-side (Design spec: "role check ต้องเกิดที่
 * layout level (server-side) ห้ามเช็ค platform_role แล้วตัดสินใจ redirect
 * ฝั่ง client-side JavaScript ล้วนๆ"). Redirects to /login for anyone
 * without a session or without an admin/moderator role -- there is no
 * "logged in but rejected" page in this app; see LoginForm's own
 * client-side sign-out-on-reject flow for the one place a `user`-role
 * account is told why, at the point they just tried to sign in.
 */
export async function requireAdminRole(): Promise<{
  userId: string;
  email: string | null;
  role: AdminRole;
}> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("platform_role")
    .eq("id", user.id)
    .single();

  const role = profile?.platform_role;
  if (role !== "admin" && role !== "moderator") {
    redirect("/login");
  }

  return { userId: user.id, email: user.email ?? null, role };
}
