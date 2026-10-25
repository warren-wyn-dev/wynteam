import { cache } from "react";
import { redirect } from "next/navigation";

import { fetchAdminAccess } from "@/lib/admin-permissions";
import { ZOKY_SYSTEMS, hasSystemAccess, type AdminLevel, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";
import { createClient } from "@/lib/supabase/server";

/**
 * The label shown in the header. Entry to ZOKY Admin never depends on it
 * (see mayEnterZokyAdmin): platform admins/moderators get in only through
 * a WYN-219 food/merchant permission like everyone else.
 */
export type AdminRole = "admin" | "moderator" | "staff";

export type AdminContext = {
  userId: string;
  email: string | null;
  role: AdminRole;
  access: AdminSystemAccess;
};

export { ZOKY_SYSTEMS, type ZokySystem } from "@/lib/admin-systems";

/**
 * Whether an account may enter ZOKY Admin at all (shared with the login
 * action): the super admin, a ZOKY Team Lead, or a food/merchant
 * permission. Fails closed when the permissions could not be read -- there
 * is no pre-WYN-219 platform_role fallback here, unlike WYNOS Admin.
 */
export function mayEnterZokyAdmin(access: AdminSystemAccess): boolean {
  if (!access.available) return false;
  return access.superAdmin || access.teamLead || ZOKY_SYSTEMS.some((system) => access.permissions[system] !== undefined);
}

/** UI check for the ทีม ZOKY page; the admin_zoky_* RPCs re-check. */
export function canManageZokyTeam(access: AdminSystemAccess): boolean {
  return access.available && (access.superAdmin || access.teamLead);
}

/**
 * Resolves the signed-in user's access and enforces the ZOKY Admin gate
 * server-side, before any child page renders. Redirects to /login for
 * anyone without a session or without food/merchant access. Cached per
 * request: the layout and the page share one lookup. Every page and RPC
 * still re-checks its own system and level.
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

  if (!mayEnterZokyAdmin(access)) {
    redirect("/login");
  }

  const platformRole = profile?.platform_role;
  const role: AdminRole = platformRole === "admin" || platformRole === "moderator" ? platformRole : "staff";
  return { userId: user.id, email: user.email ?? null, role, access };
});

/**
 * UI check for a system at a level -- the WYN-219 per-system permission.
 * The database re-checks every call.
 */
export function adminCan(ctx: AdminContext, system: AdminSystem, level: AdminLevel = "view"): boolean {
  return hasSystemAccess(ctx.access, system, level) === true;
}
