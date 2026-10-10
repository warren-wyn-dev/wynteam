import { cache } from "react";
import { redirect } from "next/navigation";

import { fetchAdminAccess } from "@/lib/admin-permissions";
import { hasSystemAccess, type AdminLevel, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";
import { createClient } from "@/lib/supabase/server";

/**
 * "staff" = an account that is neither platform admin nor moderator but holds
 * at least one WYN-219 per-system permission granted by the super admin.
 */
export type AdminRole = "admin" | "moderator" | "staff";

export type AdminContext = {
  userId: string;
  email: string | null;
  role: AdminRole;
  access: AdminSystemAccess;
};

/** Whether an account may enter WYN Admin at all (shared with the login action). */
export function mayEnterAdmin(platformRole: string | null | undefined, access: AdminSystemAccess): boolean {
  if (platformRole === "admin" || platformRole === "moderator") return true;
  return access.superAdmin || Object.keys(access.permissions).length > 0;
}

/**
 * Resolves the signed-in user's platform_role and WYN-219 access and enforces
 * the Admin gate server-side (Design spec: "role check ต้องเกิดที่ layout level
 * (server-side) ห้ามเช็ค platform_role แล้วตัดสินใจ redirect ฝั่ง client-side
 * JavaScript ล้วนๆ"). Redirects to /login for anyone without a session or
 * without any Admin access. Cached per request: the layout and the page share
 * one lookup.
 */
export const requireAdminRole = cache(async (): Promise<AdminContext> => {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const [{ data: profile }, access] = await Promise.all([
    supabase.from("profiles").select("platform_role").eq("id", user.id).single(),
    fetchAdminAccess(),
  ]);

  const platformRole = profile?.platform_role;
  if (!mayEnterAdmin(platformRole, access)) {
    redirect("/login");
  }

  const role: AdminRole = platformRole === "admin" || platformRole === "moderator" ? platformRole : "staff";
  return { userId: user.id, email: user.email ?? null, role, access };
});

/**
 * UI check for a system at a level. Once the WYN-219 foundation exists this is
 * the per-system permission; before that it falls back to the old rule
 * (staff may view, only platform admins may edit). The database re-checks
 * every call either way.
 */
export function adminCan(ctx: AdminContext, system: AdminSystem, level: AdminLevel = "view"): boolean {
  const granted = hasSystemAccess(ctx.access, system, level);
  if (granted !== null) return granted;
  return level === "view" || ctx.role === "admin";
}

/** At least one WYN-219 permission (or the super admin, or the pre-foundation fallback). */
export function adminCanAny(ctx: AdminContext): boolean {
  if (!ctx.access.available) return true;
  return ctx.access.superAdmin || Object.keys(ctx.access.permissions).length > 0;
}
